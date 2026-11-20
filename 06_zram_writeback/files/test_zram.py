#!/usr/bin/env python3
"""Sequential test of home_server's zram-pressure.service. Disposable VM only.
Run: sudo python3 test_zram.py
Creates timestamped text and CSV logs in the current working directory.
No package installation, service changes, swapoff, or writes to ZRAM sysfs.
Internal worker modes are launched only by the controller in transient units.
"""
import csv
import ctypes
import resource
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import hashlib
import json
import mmap
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import uuid
from datetime import datetime, timezone

MIB = 1024**2
Z = Path('/sys/block/zram0')
SERVICE = 'zram-pressure.service'
NORMAL_SECONDS = 360
EMERGENCY_SECONDS = 240
READBACK_STALL_SECONDS = 300  # only inactivity, no overall deadline
READBACK_PROGRESS = MIB
THREADS_PER_CPU = 4
TUNE_SECONDS = 30
TUNE_CPU_TARGET = 80.0
TUNE_MIN_GAIN = 0.05
TUNE_BAD_DROP = 0.10
TUNE_EXTRA_LEVELS = 3
TUNE_BAD_WINDOWS = 2
STAGES = ('retrieve', 'sha256', 'modify', 'discard')
AGE_SECONDS = 65
POLL = 1.0
PAGE = os.sysconf('SC_PAGE_SIZE')
MIX_PAGES = 3
MIX_BYTES = MIX_PAGES * PAGE
BD_UNIT = 4096  # bd_stat units are 4 KiB
CAPACITY_RESERVE_PCT = 15
# Linux UAPI values: Python builds do not always export these constants.
MADV_COLD = getattr(mmap, 'MADV_COLD', 20)
MADV_PAGEOUT = getattr(mmap, 'MADV_PAGEOUT', 21)
MADV_DONTNEED = getattr(mmap, 'MADV_DONTNEED', 4)
START = time.monotonic()
LOG = None
CSV = None
OUTPUT_LOCK = threading.Lock()


class Inconclusive(Exception):
    pass


class Failure(Exception):
    pass


def emit(line):
    with OUTPUT_LOCK:
        print(line, flush=True)
        if LOG is not None:
            LOG.write(line+'\n')
            LOG.flush()


def say(message):
    emit(f'[{time.monotonic()-START:6.1f}s] {message}')


CSV_FIELDS = ('elapsed_s', 'phase', 'occupancy_pct', 'psi_avg10_pct',
              'resident_bytes', 'resident_limit_bytes', 'available_bytes',
              'swap_used_bytes', 'swap_free_bytes', 'backing_units_4k',
              'backing_read_delta_4k', 'backing_write_delta_4k',
              'allocated_bytes', 'accessed_bytes', 'verified_bytes',
              'pages_modified', 'remaining_s', 'readback_rate_mib_s',
              'discarded_bytes', 'compressible_allocated_bytes', 'random_allocated_bytes',
              'same_element_allocated_bytes', 'same_element_discarded_bytes',
              'compressible_discarded_bytes', 'random_discarded_bytes',
              'orig_data_bytes', 'compr_data_bytes', 'same_pages', 'same_pages_delta',
              'same_element_logical_bytes', 'same_element_logical_pct_no_backing',
              'non_same_payload_ratio_no_backing', 'huge_pages',
              'huge_pages_since', 'compression_ratio_no_backing',
              'payload_savings_pct_no_backing', 'resident_savings_pct_no_backing',
              'readback_idle_s', 'backing_capacity_bytes', 'backing_used_bytes',
              'backing_pending_bytes', 'cold_resident_charge_bytes', 'hot_reserve_bytes',
              'swap_reserve_bytes', 'backing_reserve_bytes', 'swap_additional_bytes',
              'backing_additional_bytes', 'cold_additional_bytes', 'capacity_sample_valid',
              'resident_logical_bytes', 'resident_payload_ratio', 'resident_non_same_ratio',
              'resident_payload_savings_pct', 'resident_ram_savings_pct', 'resident_same_logical_pct',
              'readback_threads_requested', 'readback_threads_active', 'readback_worker_cpu_s',
              'retrieve_wall_s_sum', 'retrieve_cpu_s_sum', 'sha256_wall_s_sum', 'sha256_cpu_s_sum',
              'modify_wall_s_sum', 'modify_cpu_s_sum', 'discard_wall_s_sum', 'discard_cpu_s_sum',
              'readback_minor_faults', 'readback_major_faults', 'backing_read_await_ms',
              'backing_avg_queue_depth', 'system_cpu_steal_pct',
              'tune_cpu_busy_pct', 'tune_backing_mib_s', 'tune_verified_mib_s',
              'tune_state', 'record_type', 'tune_measured_threads',
              'tune_next_threads', 'tune_window_s', 'tune_gain_pct',
              'tune_best_verified_mib_s', 'tune_best_threads',
              'tune_mode', 'tune_settled_reference_mib_s')


def run(*args, timeout=10, check=True):
    return subprocess.run(args, text=True, capture_output=True, timeout=timeout,
                          check=check)


def fields(path):
    return [int(x) for x in Path(path).read_text().split()]


def meminfo():
    return {s.split(':')[0]: int(s.split()[1])*1024
            for s in Path('/proc/meminfo').read_text().splitlines()
            if s.endswith(' kB')}


def swaps():
    items = []
    for line in Path('/proc/swaps').read_text().splitlines()[1:]:
        name, _, size, used, priority = line.split()
        items.append((os.path.realpath(name), int(size)*1024,
                      int(used)*1024, int(priority)))
    return items


def service_identity():
    out = run('systemctl', 'show', SERVICE, '-p', 'ActiveState', '-p',
              'InvocationID', '-p', 'NRestarts').stdout
    data = dict(line.split('=', 1) for line in out.splitlines() if '=' in line)
    if data.get('ActiveState') != 'active' or not data.get('InvocationID'):
        raise Failure(f'{SERVICE} is not active: {data}')
    return data['InvocationID'], data.get('NRestarts')


def snapshot():
    bd_before = fields(Z/'bd_stat')
    mm = fields(Z/'mm_stat')
    original, compressed, used, limit, *_ = mm
    backing, reads, writes, *_ = fields(Z/'bd_stat')
    # Non-atomic sysfs reads: reject visibly changing or inconsistent samples.
    same = mm[5] if len(mm)>5 else None
    backed = backing * BD_UNIT
    stable = bd_before[:3] == [backing, reads, writes]
    consistent = (stable and same is not None and same >= 0 and backed >= 0
                  and original % PAGE == 0 and backed % PAGE == 0
                  and original >= backed + same*PAGE)
    comparable = consistent and backing == 0
    errors = tuple(fields(Z/'io_stat')[:2])
    if limit <= 0:
        raise Failure('ZRAM resident limit is zero or was removed')
    psi = re.search(r'^some avg10=(\d+\.\d+)',
                    Path('/proc/pressure/memory').read_text(), re.M)
    if not psi:
        raise Failure('System memory PSI unavailable')
    swap = next((x for x in swaps() if x[0] == '/dev/zram0'), None)
    if swap is None:
        raise Failure('/dev/zram0 is no longer active swap')
    return dict(original=original, compressed=compressed, used=used,
                limit=limit, occupancy=used*100//limit, psi=float(psi[1]),
                backing=backing, reads=reads, writes=writes, errors=errors,
                available=meminfo()['MemAvailable'], swap_used=swap[2],
                swap_free=swap[1]-swap[2], comparable=comparable,
                capacity_valid=consistent, same_pages=same,
                huge_pages=mm[7] if len(mm)>7 else None,
                huge_pages_since=mm[8] if len(mm)>8 else None)


def same_metrics(s):
    """Device-wide logical same-element bytes; ratio only without backing."""
    count = s.get('same_pages')
    if count is None:
        return None, None, None
    logical = count * PAGE
    if not s.get('comparable') or not s['original'] or logical > s['original']:
        return logical, None, None
    remaining = s['original'] - logical
    return logical, 100 * logical / s['original'], (remaining / s['compressed'] if s['compressed'] else None)


def compression(s):
    if not s.get('comparable') or not s['original']:
        return None, None, None
    o, c, u = s['original'], s['compressed'], s['used']
    return (o/c if c else None, 100*(1-c/o), 100*(1-u/o))


def resident_metrics(s):
    """Resident logical bytes and payload ratios under the full-page backing model."""
    if not s.get('capacity_valid'):
        return None, None, None, None, None, None
    logical = s['original'] - s['backing']*BD_UNIT
    same = s['same_pages']*PAGE
    payload = s['compressed']
    if logical <= 0 or payload < 0 or payload > logical-same or s['used'] < 0:
        return logical, None, None, None, None, None
    return (logical, logical/payload if payload else None,
            (logical-same)/payload if payload else None,
            100*(1-payload/logical), 100*(1-s['used']/logical), 100*same/logical)


def capacity(s, backing_capacity, swap_reserve, backing_reserve, cold_charge, hot_reserve):
    """Additional cold logical bytes; three logical slots, two backing slots.

    Count existing backed + pending non-same slots once. Conservatively
    charge all resident cold-worker memory; swap-cache overlap may overreserve.
    """
    if not s.get('capacity_valid'):
        return None
    backed = s['backing']*BD_UNIT
    pending = s['original']-s['same_pages']*PAGE-backed
    swap_room = max(0, s['swap_free']-swap_reserve-cold_charge-hot_reserve)
    backing_room = max(0, backing_capacity-backed-pending-backing_reserve-cold_charge-hot_reserve)
    cold_room = min(swap_room//MIX_BYTES, backing_room//(2*PAGE))*MIX_BYTES
    return dict(backed=backed, pending=pending, swap_room=swap_room,
                backing_room=backing_room, cold_room=cold_room)


class Journal:
    def __init__(self):
        self.since = f'@{time.time():.6f}'
        self.cursor = None
        self.messages = []
        self.cycles = []
        self.pending = None

    def poll(self):
        position = (['--after-cursor', self.cursor] if self.cursor else
                    ['--since', self.since])
        out = run('journalctl', '-b', '-u', SERVICE, '--no-pager',
                  '-o', 'json', *position).stdout
        for line in out.splitlines():
            if not line.startswith('{'):
                continue
            entry = json.loads(line)
            self.cursor = entry['__CURSOR']
            msg = entry.get('MESSAGE', '')
            if not isinstance(msg, str):
                continue
            self.messages.append(msg)
            say('SERVICE | '+msg)
            if 'writeback failed' in msg.lower() or 'cannot read psi/zram' in msg.lower():
                raise Failure('Service reported an error: '+msg)
            match = re.fullmatch(r'Writeback triggered: zram=(\d+)% PSI=(\d+)bp', msg)
            if match:
                self.pending = dict(index=len(self.messages)-1,
                                    occ=int(match[1]), psi=int(match[2]),
                                    emergency=False, ages=[], delta=None)
            elif self.pending is not None:
                if msg == 'Emergency writeback: all remaining eligible entries':
                    self.pending['emergency'] = True
                age = re.fullmatch(r'Writeback completed: age=(\d+)s', msg)
                if age:
                    self.pending['ages'].append(int(age[1]))
                end = re.fullmatch(r'Cycle complete; backing writes delta=(-?\d+)', msg)
                if end:
                    self.pending['delta'] = int(end[1])
                    self.cycles.append(self.pending)
                    self.pending = None


def private_mapping(length):
    return mmap.mmap(-1, length, flags=mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS,
                     prot=mmap.PROT_READ | mmap.PROT_WRITE)


def parallel_verify(m, digests, n, pool, requested, reply):
    """Process distinct pages within the oldest allocation; never fork its mapping.

    Native CDLL calls release the GIL while faults, native copies and madvise
    execute. All threads finish before the mapping is closed.
    """
    libc = ctypes.CDLL(None, use_errno=True)
    copy = libc.memcpy
    copy.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t)
    copy.restype = ctypes.c_void_p
    advise = libc.madvise
    advise.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int)
    advise.restype = ctypes.c_int
    address = ctypes.addressof(ctypes.c_char.from_buffer(m))
    count = n//PAGE
    lanes = min(requested, count)
    lock = threading.Lock()
    stop = threading.Event()
    completed = [0]*MIX_PAGES
    wall = [0]*len(STAGES)
    cpu = [0]*len(STAGES)
    faults = [0, 0]

    def lane(k):
        buf = ctypes.create_string_buffer(PAGE)
        byte = ctypes.c_ubyte()
        bufaddr = ctypes.addressof(buf)
        byteaddr = ctypes.addressof(byte)
        for i in range(k, count, lanes):
            if stop.is_set():
                break
            src = address+i*PAGE
            w, q = [0]*len(STAGES), [0]*len(STAGES)
            ru0 = resource.getrusage(resource.RUSAGE_THREAD)
            t, p = time.perf_counter_ns(), time.thread_time_ns()
            copy(bufaddr, src, PAGE)
            w[0], q[0] = time.perf_counter_ns()-t, time.thread_time_ns()-p
            t, p = time.perf_counter_ns(), time.thread_time_ns()
            digest = hashlib.sha256(buf).digest()
            w[1], q[1] = time.perf_counter_ns()-t, time.thread_time_ns()-p
            if digest != digests[i*32:(i+1)*32]:
                raise RuntimeError(f'Data integrity error: page checksum mismatch at offset {i*PAGE}')
            t, p = time.perf_counter_ns(), time.thread_time_ns()
            first = ctypes.c_ubyte.from_buffer(buf).value
            byte.value = first ^ 1
            copy(src, byteaddr, 1)
            copy(byteaddr, src, 1)
            if byte.value != first ^ 1:
                raise RuntimeError(f'Page modification failed at offset {i*PAGE}')
            byte.value = first
            copy(src, byteaddr, 1)
            copy(byteaddr, src, 1)
            if byte.value != first:
                raise RuntimeError(f'Page restoration failed at offset {i*PAGE}')
            w[2], q[2] = time.perf_counter_ns()-t, time.thread_time_ns()-p
            t, p = time.perf_counter_ns(), time.thread_time_ns()
            if advise(src, PAGE, MADV_DONTNEED) != 0:
                err = ctypes.get_errno()
                raise OSError(err, os.strerror(err))
            w[3], q[3] = time.perf_counter_ns()-t, time.thread_time_ns()-p
            ru1 = resource.getrusage(resource.RUSAGE_THREAD)
            with lock:
                completed[i % MIX_PAGES] += 1
                for stage in range(len(STAGES)):
                    wall[stage] += w[stage]
                    cpu[stage] += q[stage]
                faults[0] += ru1.ru_minflt-ru0.ru_minflt
                faults[1] += ru1.ru_majflt-ru0.ru_majflt

    futures = []
    last = 0
    last_report = time.monotonic()
    try:
        for k in range(lanes):
            futures.append(pool.submit(lane, k))
        pending = set(futures)
        while pending:
            done, pending = wait(pending, timeout=0.25, return_when=FIRST_COMPLETED)
            for future in done:
                future.result()
            with lock:
                by_type = completed.copy()
                wall_ns, cpu_ns, page_faults = wall.copy(), cpu.copy(), faults.copy()
            processed = sum(by_type)*PAGE
            now = time.monotonic()
            if processed > last and (processed-last >= READBACK_PROGRESS or now-last_report >= 1 or not pending):
                reply(processed=processed, pages=sum(by_type), discarded=processed,
                      by_type=by_type, wall_ns=wall_ns, cpu_ns=cpu_ns,
                      faults=page_faults, lanes=lanes)
                last, last_report = processed, now
        if last != n or completed != [count//MIX_PAGES]*MIX_PAGES:
            raise RuntimeError('Parallel page completion count mismatch')
    finally:
        stop.set()
        # A faulting thread may block; the controller inactivity watchdog can
        # terminate the entire transient unit. Do not close its mapping early.
        wait(futures)
    reply(verified=n, match=True, pages=count)


def cold_worker():
    """Three equal page populations, FIFO verification and per-page discard."""
    blocks = []
    def reply(**data):
        print('ZTEST '+json.dumps(data), flush=True)
    cpu_ids = sorted(os.sched_getaffinity(0))
    cpus = len(cpu_ids)
    requested = THREADS_PER_CPU*cpus
    if requested < 1:
        raise RuntimeError('No available CPUs for readback')
    # Smaller native stacks keep large CPU-count VMs within the worker cgroup.
    threading.stack_size(256*1024)
    pool = None
    pool_size = 0
    reply(ready=True, cpus=cpus, cpu_ids=cpu_ids, threads=requested)
    for line in sys.stdin:
        command = json.loads(line)
        if command['op'] == 'alloc':
            n = command['n']
            if n <= 0 or n % MIX_BYTES:
                raise ValueError('Cold allocations must contain a multiple of three pages')
            m = private_mapping(n)
            # Repeated non-uniform 64-byte pattern; not a same-element page.
            pattern = bytes(range(64))
            repeated = (pattern*((PAGE+len(pattern)-1)//len(pattern)))[:PAGE]
            digests = bytearray()
            try:
                for i in range(n//PAGE):
                    kind = i % MIX_PAGES
                    if kind == 0:
                        page = repeated
                    elif kind == 1:
                        page = os.urandom(PAGE)
                    else:
                        # Nonzero repeated byte gives identical machine words.
                        # Touch the whole page, rather than rely on zero-page sharing.
                        page = bytes([1 + (i // MIX_PAGES) % 255]) * PAGE
                    m[i*PAGE:(i+1)*PAGE] = page
                    digests.extend(hashlib.sha256(page).digest())
                del page
                m.madvise(MADV_COLD)
                m.madvise(MADV_PAGEOUT)
                blocks.append((m, digests, n))
            except BaseException:
                m.close()
                raise
            reply(allocated=n, compressible=n//3, random=n//3, same_element=n//3)
        elif command['op'] == 'verify':
            if not blocks:
                reply(done=True)
                continue
            requested = command.get('threads')
            if type(requested) is not int or requested < 1:
                raise ValueError('Invalid readback thread count')
            m, digests, n = blocks.pop(0)
            # A previous block has fully drained; no outstanding page faults.
            pool_target = min(requested, n//PAGE)
            if pool is None or pool_size != pool_target:
                if pool is not None:
                    pool.shutdown(wait=True)
                pool = ThreadPoolExecutor(max_workers=pool_target)
                pool_size = pool_target
            try:
                parallel_verify(m, digests, n, pool, requested, reply)
            except Exception as e:
                reply(error=str(e))
                return
            finally:
                m.close()
        elif command['op'] == 'exit':
            break
        else:
            raise ValueError('Invalid internal command')
    if pool is not None:
        pool.shutdown(wait=True)
    for m, _, _ in blocks:
        m.close()


def hot_worker(n):
    """A separate cgroup's memory.high induces real reclaim stalls."""
    m = private_mapping(n)
    # Nonuniform random data; touch all pages continuously.
    for offset in range(0, n, PAGE):
        m[offset:offset+PAGE] = os.urandom(PAGE)
    while True:
        for offset in range(0, n, PAGE):
            m[offset] = (m[offset]+1) % 256


class Worker:
    def __init__(self, units, mode, resident, swap, n=None, high=None, runtime=900):
        self.unit = f'zram-test-{mode}-{uuid.uuid4().hex[:12]}.service'
        units.append(self.unit)  # Register before launch, including failed starts.
        cmd = ['systemd-run', '--quiet', '--wait', '--pipe', '--collect',
               '--unit='+self.unit, '-p', 'MemoryAccounting=yes',
               '-p', f'MemoryMax={resident}', '-p', f'MemorySwapMax={swap}',
               '-p', 'OOMPolicy=stop', '-p',
               f'RuntimeMaxSec={runtime}s' if runtime is not None else 'RuntimeMaxSec=infinity',
               '-p', 'TimeoutStopSec=5s']
        if high is not None:
            cmd += ['-p', f'MemoryHigh={high}']
        cmd += [sys.executable, '-u', str(Path(__file__).resolve()), '--'+mode+'-worker']
        if n is not None:
            cmd.append(str(n))
        self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.messages = queue.Queue()
        def reader():
            for line in self.proc.stdout:
                if line.startswith('ZTEST '):
                    try:
                        self.messages.put(json.loads(line[6:]))
                    except ValueError:
                        self.messages.put({'error': line.rstrip()})
                else:
                    say('WORKER | '+line.rstrip())
        self.thread = threading.Thread(target=reader, daemon=True)
        self.thread.start()

    def check(self):
        if self.proc.poll() is not None:
            raise Failure(f'{self.unit} exited unexpectedly ({self.proc.returncode})')

    def send(self, **command):
        self.check()
        self.proc.stdin.write(json.dumps(command)+'\n')
        self.proc.stdin.flush()

    def stop(self):
        result = run('systemctl', 'stop', self.unit, timeout=15, check=False)
        if self.proc.poll() is None:
            try:
                self.proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                self.proc.terminate()
                try:
                    self.proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.proc.kill()
                    self.proc.wait(timeout=3)
        state = run('systemctl', 'show', self.unit, '-p', 'ActiveState',
                    '--value', check=False).stdout.strip()
        if state not in ('inactive', 'failed') and state != '':
            raise Failure(f'Cleanup could not confirm stopped unit {self.unit}: {state}')
        if result.returncode and state not in ('inactive', 'failed'):
            # A collected unit is absent; distinguish that from a bus error.
            if not any(s in result.stderr.lower() for s in ('not loaded', 'not found')):
                raise Failure(f'Cleanup of {self.unit}: {result.stderr.strip()}')


class Test:
    def __init__(self):
        self.units = []
        self.workers = []
        self.cold = None
        self.hot = None
        self.journal = Journal()
        self.total = 0
        self.allocations = []
        self.readback_threads = 0
        self.readback_active = 0
        self.cpu_ids = []
        self.tune_step = 0
        self.tune_limit = 0
        self.tune_sample = None
        self.tune_best_rate = None
        self.tune_best_threads = None
        self.tune_flat = 0
        self.tune_reference = None
        self.tune_candidates = {}
        self.tune_trial = []
        self.tune_history = {}
        self.tune_settled_rate = None
        self.tune_mode = 'search'
        self.tune_state = 'pending'
        self.tune_metrics = (None, None, None)
        self.stage_wall = [0]*len(STAGES)
        self.stage_cpu = [0]*len(STAGES)
        self.readback_faults = [0, 0]
        self.disk_stat = None
        self.io_sample = None
        self.io_metrics = (None, None, None)
        self.verified = 0
        self.accessed = 0
        self.pages_modified = 0
        self.discarded = 0
        self.discarded_by_type = [0, 0, 0]
        self.compression_peak = None
        self.resident_peak = None
        self.cold_charge_file = None
        self.capacity_block = None
        self.readback_started = None
        self.last_progress = None
        self.display_phase = None
        self.display_rows = 0
        self.phase_evidence = {}
        self.phase = 'PREFLIGHT'
        self.last_display = 0
        self.last_check = 0
        self.deadline = time.monotonic()+30
        self.results = {}

    def preflight(self):
        if os.geteuid() != 0:
            raise Failure('Run with sudo python3 test_zram.py')
        if not Path('/sys/fs/cgroup/cgroup.controllers').is_file():
            raise Failure('cgroup v2 is required')
        if not {'memory'} <= set(Path('/sys/fs/cgroup/cgroup.controllers').read_text().split()):
            raise Failure('cgroup memory controller is unavailable')
        if sys.platform != 'linux' or not hasattr(mmap.mmap, 'madvise'):
            raise Failure('Linux Python mmap.madvise is required')
        for name in ('idle', 'writeback', 'mm_stat', 'bd_stat', 'io_stat'):
            if not (Z/name).exists():
                raise Failure(f'Missing {Z/name}')
        if (Z/'compressed_writeback').read_text().strip() != '1':
            raise Failure('Compressed writeback is not enabled')
        if (Z/'writeback_limit_enable').read_text().strip() != '0':
            raise Failure('Writeback limit is enabled; no configuration changed')
        backing = (Z/'backing_dev').read_text().strip()
        if backing in ('', 'none', '[none]'):
            raise Failure('No backing device configured')
        entries = swaps()
        zswap = Path('/sys/module/zswap/parameters/enabled')
        if zswap.exists() and zswap.read_text().strip().lower() in ('y', '1', 'yes'):
            raise Failure('zswap is enabled and can intercept the intended workload')
        z = next((x for x in entries if x[0] == '/dev/zram0'), None)
        if z is None:
            raise Failure('zram0 is not active swap')
        if any(x[0] != z[0] and x[3] >= z[3] for x in entries):
            raise Inconclusive('Another swap has equal/higher priority; cannot isolate zram0')
        if os.path.realpath(backing) in [x[0] for x in entries]:
            raise Failure('Backing device is also active ordinary swap')
        self.identity = service_identity()
        self.base = snapshot()
        s = self.base
        if not s['capacity_valid']:
            raise Inconclusive('Initial backing/logical counters inconsistent; retry on a quiet VM')
        device_bytes = int(run('blockdev', '--getsize64', backing).stdout.strip())
        # Optional block-layer instrumentation, not a new preflight gate.
        self.disk_stat = Path('/sys/class/block')/Path(os.path.realpath(backing)).name/'stat'
        # Slot zero is reserved; usable capacity is rounded to whole pages.
        self.backing_capacity = max(0, device_bytes//PAGE-1)*PAGE
        if self.backing_capacity <= 0 or s['backing']*BD_UNIT > self.backing_capacity:
            raise Failure('Invalid backing capacity or occupancy')
        self.swap_reserve = (s['swap_free']*CAPACITY_RESERVE_PCT+99)//100
        self.backing_reserve = ((self.backing_capacity-s['backing']*BD_UNIT)*CAPACITY_RESERVE_PCT+99)//100
        ram = meminfo()['MemTotal']
        # Reserve other system memory and swap. Bounded test-only allocation.
        self.reserve = max(128*MIB, ram//16)
        self.resident = min(256*MIB, s['available']//4, ram//8)
        self.hot_size = min(96*MIB, max(16*MIB, s['limit']//25))//PAGE*PAGE
        self.hot_max = self.hot_size+48*MIB
        # The cgroup ceiling bounds swap, not total logical allocations.
        self.swap_ceiling = max(0, s['swap_free']-self.swap_reserve)//PAGE*PAGE
        self.hot_reserve = self.hot_max+self.hot_size+16*MIB
        initial = capacity(s, self.backing_capacity, self.swap_reserve,
                           self.backing_reserve, 0, self.hot_reserve)
        self.chunk = max(MIX_BYTES, min(32*MIB, self.resident//8)//MIX_BYTES*MIX_BYTES)
        if s['occupancy'] >= 70:
            raise Inconclusive('Baseline occupancy >=70%; use a quiet VM')
        if self.resident < 64*MIB or s['available'] < self.reserve+self.resident+self.hot_max:
            raise Inconclusive('Insufficient available RAM for bounded worker cgroups')
        if initial['cold_room'] < MIX_BYTES:
            raise Inconclusive('No capacity for a cold page triplet after reserves')
        say(f'Kernel={os.uname().release}; backing={backing}; '
            f'RAM={ram/MIB:.0f} MiB; resident limit={s["limit"]/MIB:.0f} MiB')
        say(f'Usable backing={self.backing_capacity/MIB:.1f} MiB; initial cold allowance={initial["cold_room"]/MIB:.1f} MiB')
        say(f'Logical swap reserve={self.swap_reserve/MIB:.1f} MiB; backing reserve={self.backing_reserve/MIB:.1f} MiB; hot allowance={self.hot_reserve/MIB:.1f} MiB')
        say(f'Cold swap ceiling={self.swap_ceiling/MIB:.0f} MiB; cold RAM cap={self.resident/MIB:.0f} MiB; system RAM reserve={self.reserve/MIB:.0f} MiB')
        say('WARNING: deliberate memory/swap pressure and SSD writes; disposable VM only.')
        # Controller deadlines/watchdog govern the cold worker, not systemd.
        say('Cold workload: exactly 1/3 repeated-pattern, 1/3 random, 1/3 nonzero same-element pages.')
        say('Hot worker separately random; kernel counters are device-wide.')
        say('Adaptive capacity: three logical slots, at most two backing slots per cold triplet.')
        self.cold = Worker(self.units, 'cold', self.resident, self.swap_ceiling, runtime=None)
        self.workers.append(self.cold)
        ready = self.receive(self.cold)
        if not ready.get('ready'):
            raise Failure('Cold worker did not initialize')
        cpus, threads, cpu_ids = ready.get('cpus'), ready.get('threads'), ready.get('cpu_ids')
        if (type(cpus) is not int or cpus < 1 or threads != THREADS_PER_CPU*cpus
                or not isinstance(cpu_ids, list) or len(cpu_ids) != cpus
                or any(type(i) is not int or i < 0 for i in cpu_ids)
                or len(set(cpu_ids)) != cpus):
            raise Failure(f'Invalid cold worker CPU/thread report: {ready}')
        self.cpu_ids = cpu_ids
        self.tune_step = threads
        self.readback_threads = threads
        say(f'Readback starts at {cpus} available logical CPUs x {THREADS_PER_CPU} = {threads} threads; adaptive growth.')
        group = run('systemctl', 'show', self.cold.unit, '-p', 'ControlGroup', '--value').stdout.strip()
        if not group.startswith('/') or group == '/' or '..' in Path(group).parts:
            raise Failure('Cannot identify cold worker cgroup')
        self.cold_charge_file = Path('/sys/fs/cgroup')/group.lstrip('/')/'memory.current'
        if not self.cold_charge_file.is_file():
            raise Failure('Cold worker memory.current unavailable')

    def capacity_state(self, s):
        charge = (int(self.cold_charge_file.read_text()) if self.cold_charge_file is not None
                  else (self.resident if self.cold is not None else 0))
        hot = self.hot_reserve if self.phase in ('PREFLIGHT', 'NORMAL') or self.hot is not None else 0
        return charge, hot, capacity(s, self.backing_capacity, self.swap_reserve,
                                     self.backing_reserve, charge, hot)

    def tick(self):
        if self.deadline is not None and time.monotonic() >= self.deadline:
            raise Inconclusive(f'{self.phase} timed out')
        s = snapshot()
        if self.total and s['comparable'] and s['original'] > self.base['original'] and (self.compression_peak is None or s['original'] > self.compression_peak['original']):
            self.compression_peak = dict(s)
        logical, ratio, *_ = resident_metrics(s)
        if self.total and ratio is not None and (self.resident_peak is None or logical > self.resident_peak['original']-self.resident_peak['backing']*BD_UNIT):
            self.resident_peak = dict(s)
        if s['limit'] != self.base['limit']:
            raise Failure('ZRAM resident limit changed during test')
        if s['errors'] != self.base['errors']:
            raise Failure(f'ZRAM storage I/O error counters changed: {self.base["errors"]} -> {s["errors"]}')
        if s['available'] < self.reserve:
            raise Inconclusive('System RAM headroom fell below test reserve')
        for worker in (self.cold, self.hot):
            if worker:
                worker.check()
        if time.monotonic()-self.last_check >= 2:
            if service_identity() != self.identity:
                raise Failure('Pressure monitor restarted during test')
            self.journal.poll()
            self.last_check = time.monotonic()
        if self.phase == 'READBACK' and self.last_progress is not None:
            if time.monotonic()-self.last_progress >= READBACK_STALL_SECONDS:
                raise Inconclusive(f'READBACK made no verified/discarded page progress for {READBACK_STALL_SECONDS}s; last confirmed {self.discarded/MIB:.1f} MiB')
        if time.monotonic()-self.last_display >= 2 or self.display_phase != self.phase:
            self.display(s)
            self.last_display = time.monotonic()
        return s

    def sample_io(self, now):
        """Interval block statistics and system CPU steal; absence is not failure."""
        try:
            disk = fields(self.disk_stat) if self.disk_stat is not None else []
            d = (disk[0], disk[3], disk[10]) if len(disk) >= 11 else None
        except (OSError, ValueError):
            d = None
        try:
            cpu = [int(x) for x in Path('/proc/stat').read_text().splitlines()[0].split()[1:9]]
            u = (sum(cpu), cpu[7]) if len(cpu) == 8 else None
        except (OSError, ValueError, IndexError):
            u = None
        prev = self.io_sample
        self.io_sample = (now, d, u)
        await_ms = depth = steal = None
        if prev is not None and now > prev[0]:
            if d is not None and prev[1] is not None:
                dr, dm, dw = (a-b for a, b in zip(d, prev[1]))
                if min(dr, dm, dw) >= 0:
                    await_ms = dm/dr if dr else None
                    depth = dw/(1000*(now-prev[0]))
            if u is not None and prev[2] is not None:
                dt, ds = (a-b for a, b in zip(u, prev[2]))
                if dt > 0 and 0 <= ds <= dt:
                    steal = 100*ds/dt
        self.io_metrics = (await_ms, depth, steal)

    def display(self, s):
        now = time.monotonic()
        if self.phase == 'READBACK':
            self.sample_io(now)
        remaining = max(0, self.deadline-now) if self.deadline is not None else None
        idle = max(0, now-self.last_progress) if self.phase == 'READBACK' and self.last_progress is not None else None
        ratio, payload_saving, resident_saving = compression(s)
        same_bytes, same_pct, non_same_ratio = same_metrics(s)
        logical, live_ratio, live_non_same, live_payload_save, live_ram_save, live_same_pct = resident_metrics(s)
        charge, hot, cap = self.capacity_state(s)
        same_delta = (s['same_pages']-self.base['same_pages'] if s['same_pages'] is not None and self.base['same_pages'] is not None else None)
        rate = (self.accessed/MIB/max(0.001, now-self.readback_started)
                if self.readback_started is not None else 0)
        writes = (s['writes']-self.base['writes'])/256
        reads = (s['reads']-self.base['reads'])/256
        header = self.display_phase != self.phase or self.display_rows % 18 == 0
        if self.display_phase != self.phase:
            self.display_rows = 0
            self.display_phase = self.phase
            emit(f'--- {self.phase} | memory and I/O in MiB; W+/R+ since start ---')
        if self.phase == 'READBACK':
            eta = (max(0,self.total-self.accessed)/MIB/rate if rate > 0 else None)
            eta_text = f'{eta:.0f}' if eta is not None else '-'
            if header:
                emit('   Time |   Read+ | Discarded |   Swap |  MiB/s | Thr | ETA s | Idle')
                emit('-'*70)
            emit(f'{now-START:7.1f} | {reads:7.1f} | {self.discarded/MIB:9.1f} | '
                 f'{s["swap_used"]/MIB:6.1f} | {rate:6.2f} |{self.readback_active:4}|{eta_text:>6}|{idle:5.0f}')
        else:
            if header:
                emit('   Time |Occ%| PSI%|  ZRAM |   Swap |   Back |Ratio| Cold+ |Left')
                emit('-'*71)
            ratio_text = f'{live_ratio:.2f}' if live_ratio is not None else '-'
            room_text = f'{cap["cold_room"]/MIB:.0f}' if cap is not None else '-'
            emit(f'{now-START:7.1f} |{s["occupancy"]:4}|{s["psi"]:5.2f}|{s["used"]/MIB:7.1f}| '
                 f'{s["swap_used"]/MIB:6.1f} | {s["backing"]/256:6.1f} |{ratio_text:>5}|{room_text:>6} |{remaining:4.0f}')
        self.display_rows += 1
        if CSV is not None:
            CSV.writerow(dict(elapsed_s=f'{now-START:.3f}', phase=self.phase,
                occupancy_pct=s['occupancy'], psi_avg10_pct=s['psi'],
                resident_bytes=s['used'], resident_limit_bytes=s['limit'],
                available_bytes=s['available'], swap_used_bytes=s['swap_used'],
                swap_free_bytes=s['swap_free'], backing_units_4k=s['backing'],
                backing_read_delta_4k=s['reads']-self.base['reads'],
                backing_write_delta_4k=s['writes']-self.base['writes'],
                allocated_bytes=self.total, accessed_bytes=self.accessed,
                verified_bytes=self.verified, pages_modified=self.pages_modified,
                remaining_s=f'{remaining:.1f}' if remaining is not None else '',
                readback_rate_mib_s=f'{rate:.3f}', discarded_bytes=self.discarded,
                compressible_allocated_bytes=self.total//3, random_allocated_bytes=self.total//3,
                same_element_allocated_bytes=self.total//3,
                compressible_discarded_bytes=self.discarded_by_type[0],
                random_discarded_bytes=self.discarded_by_type[1],
                same_element_discarded_bytes=self.discarded_by_type[2],
                orig_data_bytes=s['original'], compr_data_bytes=s['compressed'],
                same_pages=s['same_pages'], same_pages_delta=same_delta,
                same_element_logical_bytes=same_bytes, same_element_logical_pct_no_backing=same_pct,
                non_same_payload_ratio_no_backing=non_same_ratio,
                huge_pages=s['huge_pages'], huge_pages_since=s['huge_pages_since'],
                compression_ratio_no_backing=ratio, payload_savings_pct_no_backing=payload_saving,
                resident_savings_pct_no_backing=resident_saving, readback_idle_s=idle,
                backing_capacity_bytes=self.backing_capacity, backing_used_bytes=s['backing']*BD_UNIT,
                backing_pending_bytes=cap['pending'] if cap is not None else None,
                cold_resident_charge_bytes=charge, hot_reserve_bytes=hot,
                swap_reserve_bytes=self.swap_reserve, backing_reserve_bytes=self.backing_reserve,
                swap_additional_bytes=cap['swap_room'] if cap is not None else None,
                backing_additional_bytes=cap['backing_room'] if cap is not None else None,
                cold_additional_bytes=cap['cold_room'] if cap is not None else None,
                capacity_sample_valid=int(cap is not None), resident_logical_bytes=logical,
                resident_payload_ratio=live_ratio, resident_non_same_ratio=live_non_same,
                resident_payload_savings_pct=live_payload_save, resident_ram_savings_pct=live_ram_save,
                resident_same_logical_pct=live_same_pct,
                readback_threads_requested=self.readback_threads,
                readback_threads_active=self.readback_active,
                readback_worker_cpu_s=sum(self.stage_cpu)/1e9,
                retrieve_wall_s_sum=self.stage_wall[0]/1e9, retrieve_cpu_s_sum=self.stage_cpu[0]/1e9,
                sha256_wall_s_sum=self.stage_wall[1]/1e9, sha256_cpu_s_sum=self.stage_cpu[1]/1e9,
                modify_wall_s_sum=self.stage_wall[2]/1e9, modify_cpu_s_sum=self.stage_cpu[2]/1e9,
                discard_wall_s_sum=self.stage_wall[3]/1e9, discard_cpu_s_sum=self.stage_cpu[3]/1e9,
                readback_minor_faults=self.readback_faults[0], readback_major_faults=self.readback_faults[1],
                backing_read_await_ms=self.io_metrics[0], backing_avg_queue_depth=self.io_metrics[1],
                system_cpu_steal_pct=self.io_metrics[2],
                tune_cpu_busy_pct=self.tune_metrics[0], tune_backing_mib_s=self.tune_metrics[1],
                tune_verified_mib_s=self.tune_metrics[2], tune_state=self.tune_state,
                record_type='sample', tune_best_verified_mib_s=self.tune_best_rate,
                tune_best_threads=self.tune_best_threads, tune_mode=self.tune_mode,
                tune_settled_reference_mib_s=self.tune_settled_rate))

    def receive(self, worker):
        while True:
            self.tick()
            try:
                msg = worker.messages.get(timeout=POLL)
            except queue.Empty:
                continue
            if 'error' in msg:
                raise Failure(msg['error'])
            return msg

    def alloc(self, s, target):
        # Near a threshold, use smaller steps. Never allocate blindly above it.
        gap = max(PAGE, (target*s['limit']//100)-s['used'])
        _, _, cap = self.capacity_state(s)
        if cap is None:
            # Concurrent backing I/O: defer and re-sample without allocating.
            time.sleep(POLL)
            return True
        n = min(self.chunk, max(MIX_BYTES, gap//2), cap['cold_room'])//MIX_BYTES*MIX_BYTES
        if n <= 0:
            reason = ('logical swap headroom' if cap['swap_room']//MIX_BYTES <= cap['backing_room']//(2*PAGE)
                      else 'backing headroom (occupied + pending + reserves)')
            if self.capacity_block != reason:
                say('Allocation paused: '+reason)
                self.capacity_block = reason
            return False
        self.capacity_block = None
        self.cold.send(op='alloc', n=n)
        msg = self.receive(self.cold)
        if msg.get('allocated') != n or any(msg.get(k) != n//3 for k in ('compressible', 'random', 'same_element')):
            raise Failure(f'Unexpected allocation reply: {msg}')
        self.total += n
        self.allocations.append(n)
        return True

    def sleep(self, seconds):
        end = time.monotonic()+seconds
        while time.monotonic() < end:
            self.tick()
            time.sleep(min(POLL, max(0, end-time.monotonic())))

    def normal(self):
        self.phase = 'NORMAL'
        self.deadline = time.monotonic()+NORMAL_SECONDS
        self.journal.poll()
        marker = len(self.journal.messages)
        before = snapshot()['writes']
        say('1/3 NORMAL: prefill to 76%, age cold pages for 65s, then apply hot pressure.')
        def passed():
            return any(c['index'] >= marker and 80 <= c['occ'] < 95 and c['psi'] >= 500
                       and not c['emergency'] and c['ages'] and c['delta'] > 0
                       for c in self.journal.cycles)
        while True:
            s = self.tick()
            if s['occupancy'] >= 76:
                break
            if not self.alloc(s, 77):
                raise Inconclusive('Capacity exhausted before normal prefill: '+str(self.capacity_block))
        say('Cold pages aging; no test pages are accessed during this interval.')
        self.sleep(AGE_SECONDS)
        try:
            self.hot = Worker(self.units, 'hot', self.hot_max, self.hot_size+16*MIB,
                              n=self.hot_size, high=max(16*MIB, self.hot_size//2))
            self.workers.append(self.hot)
            while True:
                s = self.tick()
                if passed() and s['writes'] > before:
                    say('PASS NORMAL: journal-confirmed normal trigger and positive backing writes.')
                    return
                if s['occupancy'] < 89 and self.alloc(s, 87 if s['occupancy'] < 87 else 90):
                    continue
                time.sleep(POLL)
        finally:
            if self.hot:
                self.hot.stop()
                self.workers.remove(self.hot)
                self.units.remove(self.hot.unit)
                self.hot = None

    def emergency(self):
        self.phase = 'EMERGENCY'
        self.deadline = time.monotonic()+EMERGENCY_SECONDS
        say('2/3 EMERGENCY: stop hot pressure; allow 35s for PSI/retry cooldown.')
        self.sleep(35)
        self.journal.poll()
        marker = len(self.journal.messages)
        before = snapshot()['writes']
        seen_trigger = False
        while True:
            s = self.tick()
            cycles = [c for c in self.journal.cycles if c['index'] >= marker and c['occ'] >= 95]
            if cycles and not seen_trigger:
                say('Emergency threshold observed in service journal; checking all-eligible fallback.')
                seen_trigger = True
            if any(c['emergency'] and c['delta'] > 0 for c in cycles) and s['writes'] > before:
                say('PASS EMERGENCY: >=95% trigger, explicit emergency branch and positive cycle writes.')
                return
            # Keep newly swapped pages young. If old entries reclaim enough first,
            # refill and try again without artificially modifying idle timestamps.
            if s['occupancy'] < 96 and self.alloc(s, 97):
                continue
            time.sleep(POLL)

    def tune_point(self):
        """CPU busy ticks over the worker's affinity mask, excluding wait/steal."""
        wanted = {f'cpu{i}' for i in self.cpu_ids}
        rows = {}
        try:
            for line in Path('/proc/stat').read_text().splitlines():
                parts = line.split()
                if parts and parts[0] in wanted:
                    v = [int(x) for x in parts[1:9]]
                    if len(v) != 8:
                        return None
                    # user, nice, system, idle, iowait, irq, softirq, steal
                    rows[parts[0]] = (sum(v), sum(v[i] for i in (0,1,2,5,6)))
            if set(rows) != wanted:
                return None
            return (time.monotonic(), self.verified, fields(Z/'bd_stat')[1],
                    sum(x[0] for x in rows.values()), sum(x[1] for x in rows.values()))
        except (OSError, ValueError, IndexError):
            return None

    def remember_tune_rate(self, threads, rate):
        self.tune_candidates[threads] = rate
        self.tune_best_rate = max(self.tune_candidates.values())
        self.tune_best_threads = min(k for k, v in self.tune_candidates.items()
                                     if v >= self.tune_best_rate*(1-TUNE_MIN_GAIN))

    def settle_tune(self, reason):
        self.readback_threads = self.tune_best_threads
        self.tune_settled_rate = self.tune_candidates[self.readback_threads]
        self.tune_mode = 'settled'
        self.tune_trial.clear()
        self.tune_state = reason

    def historical_rates(self):
        # Keep every window; exclude CPU-saturated samples from candidate ranking.
        rates = {}
        for threads, windows in self.tune_history.items():
            safe = [(rate, dt) for rate, dt, cpu in windows if cpu < TUNE_CPU_TARGET]
            if safe and windows[-1][2] < TUNE_CPU_TARGET:
                rates[threads] = sum(r*t for r,t in safe)/sum(t for _,t in safe)
        return rates

    def retune_candidate(self, old):
        rates = self.historical_rates()
        if rates:
            best = max(rates.values())
            promising = [k for k, v in rates.items()
                         if k != old and k <= self.tune_limit
                         and v >= best*(1-TUNE_MIN_GAIN)]
            if promising:
                return min(promising)
        # Prefer an unexplored level over repeating a known poor candidate.
        saturated = [k for k, w in self.tune_history.items()
                     if w[-1][2] >= TUNE_CPU_TARGET]
        limit = min([self.tune_limit] + [k-1 for k in saturated])
        return next((k for k in range(old+self.tune_step, limit+1, self.tune_step)
                     if k not in self.tune_history), None)

    def tune_decision(self, now, cpu_pct, verified_rate, dt):
        old = self.readback_threads
        self.tune_history.setdefault(old, []).append((verified_rate, dt, cpu_pct))
        if cpu_pct >= TUNE_CPU_TARGET:
            self.readback_threads = max(1, old-self.tune_step if old > self.tune_step else old//2)
            self.tune_mode = 'settled'
            self.tune_settled_rate = None
            self.tune_trial.clear()
            self.tune_candidates.clear()
            self.tune_best_rate = self.tune_best_threads = None
            self.tune_state = 'CPU target; back off'
            return
        if self.tune_mode == 'settled':
            if self.tune_settled_rate is None:
                self.tune_settled_rate = verified_rate
                self.tune_candidates.clear()
                self.remember_tune_rate(old, verified_rate)
                self.tune_state = 'settled baseline'
                return
            if verified_rate >= self.tune_settled_rate*(1-TUNE_BAD_DROP):
                self.tune_trial.clear()
                self.tune_state = 'hold; stable throughput'
                return
            self.tune_trial.append((verified_rate, dt))
            if len(self.tune_trial) < TUNE_BAD_WINDOWS:
                self.tune_state = 'hold; confirm deterioration'
                return
            baseline = sum(r*t for r,t in self.tune_trial)/sum(t for _,t in self.tune_trial)
            candidate = self.retune_candidate(old)
            # Refresh the local comparison, never the lifetime history.
            self.tune_candidates.clear()
            self.remember_tune_rate(old, baseline)
            self.tune_trial.clear()
            if candidate is None:
                self.tune_settled_rate = baseline
                self.tune_state = 'hold; refreshed baseline, no useful candidate'
                return
            self.readback_threads = candidate
            self.tune_mode = 'retune'
            self.tune_state = 'sustained deterioration; compare candidate'
            return
        self.tune_trial.append((verified_rate, dt))
        trial_rate = sum(r*t for r,t in self.tune_trial)/sum(t for _,t in self.tune_trial)
        if self.tune_mode == 'retune':
            if len(self.tune_trial) < TUNE_BAD_WINDOWS:
                self.tune_state = 'confirm retune candidate'
                return
            self.remember_tune_rate(old, trial_rate)
            self.settle_tune('retune complete; hold near-best count')
            return
        best = self.tune_best_rate
        bad = best is not None and trial_rate < best*(1-TUNE_BAD_DROP)
        if bad and len(self.tune_trial) < TUNE_BAD_WINDOWS:
            self.tune_state = 'confirm slowdown'
            return
        if bad:
            self.settle_tune('confirmed slowdown; hold near-best count')
            return
        self.remember_tune_rate(old, trial_rate)
        if self.tune_reference is None or trial_rate >= self.tune_reference*(1+TUNE_MIN_GAIN):
            self.tune_reference = trial_rate
            self.tune_flat = 0
        else:
            self.tune_flat += 1
        self.tune_trial.clear()
        if self.tune_flat > TUNE_EXTRA_LEVELS:
            self.settle_tune('plateau; hold near-best count')
            return
        self.readback_threads = min(self.tune_limit, old+self.tune_step)
        if self.readback_threads == old:
            self.settle_tune('page-count limit; hold near-best count')
        else:
            self.tune_state = 'explore higher' if self.tune_flat else 'increase'

    def tune_readback(self, block):
        """Tune at block boundaries; objective is verified and discarded bytes/s."""
        point = self.tune_point()
        if point is None:
            self.tune_sample = None
            self.tune_trial.clear()
            say(f'TUNE: {self.readback_threads} threads | counters unavailable; hold')
            return
        if block//PAGE < self.readback_threads:
            # Do not attribute a short, underfilled block to a higher target.
            self.tune_sample = point
            self.tune_trial.clear()
            return
        if self.tune_sample is None:
            self.tune_sample = point
            return
        dt, dv, dr, ticks, busy = (a-b for a,b in zip(point, self.tune_sample))
        if dt < TUNE_SECONDS:
            return
        self.tune_sample = point
        if ticks <= 0 or not 0 <= busy <= ticks or min(dv, dr) < 0:
            self.tune_trial.clear()
            say(f'TUNE: {self.readback_threads} threads | inconsistent counters; hold')
            return
        cpu_pct = 100*busy/ticks
        disk_rate = dr*BD_UNIT/MIB/dt
        verified_rate = dv/MIB/dt
        self.tune_metrics = (cpu_pct, disk_rate, verified_rate)
        old = self.readback_threads
        previous_best = self.tune_best_rate
        gain = 100*(verified_rate/previous_best-1) if previous_best else None
        # A resident/same-element-only window still represents useful work.
        if self.verified == self.total:
            self.tune_history.setdefault(old, []).append((verified_rate, dt, cpu_pct))
            self.tune_state = 'complete; no further tuning'
        elif dv > 0 or cpu_pct >= TUNE_CPU_TARGET:
            self.tune_decision(point[0], cpu_pct, verified_rate, dt)
        else:
            self.tune_state = 'no verified progress; hold'
            self.tune_trial.clear()
        gain_text = f'{gain:+.1f}' if gain is not None else '-'
        emit('TUNE | Thr | CPU% | Read/s | Done/s | Gain% | Next | Decision')
        emit(f'     |{old:4}|{cpu_pct:5.1f}|{disk_rate:7.2f}|{verified_rate:7.2f}|{gain_text:>6}|{self.readback_threads:5}| {self.tune_state}')
        if CSV is not None:
            CSV.writerow(dict(record_type='tuning', phase='READBACK',
                elapsed_s=f'{point[0]-START:.3f}', verified_bytes=self.verified,
                discarded_bytes=self.discarded, tune_measured_threads=old,
                tune_next_threads=self.readback_threads, tune_window_s=dt,
                tune_cpu_busy_pct=cpu_pct, tune_backing_mib_s=disk_rate,
                tune_verified_mib_s=verified_rate, tune_gain_pct=gain,
                tune_best_verified_mib_s=self.tune_best_rate,
                tune_best_threads=self.tune_best_threads, tune_state=self.tune_state,
                tune_mode=self.tune_mode, tune_settled_reference_mib_s=self.tune_settled_rate))

    def readback(self):
        self.phase = 'READBACK'
        self.readback_started = self.last_progress = time.monotonic()
        self.deadline = None
        before = snapshot()['reads']
        say(f'3/3 READBACK: oldest first; access, flip/restore one bit per page, '
            f'verify SHA-256 and immediately discard all {self.total/MIB:.1f} MiB.')
        say(f'No overall readback deadline; no-progress timeout {READBACK_STALL_SECONDS}s.')
        say(f'Parallel readback: starts at {self.readback_threads} threads; increase by {self.tune_step} per trial.')
        say(f'Tuning: >= {TUNE_SECONDS}s windows; {TUNE_CPU_TARGET:.0f}% busy CPU target; verified/discarded MiB/s objective.')
        say(f'Explore {TUNE_EXTRA_LEVELS} further levels after first plateau; confirm >{TUNE_BAD_DROP*100:.0f}% slowdown twice; retune only after sustained deterioration.')
        say('Keep all tuning measurements; prefer the lowest near-best count.')
        self.tune_state = 'ramping'
        if not self.total:
            raise Inconclusive('No cold data allocated')
        self.tune_limit = max(self.allocations)//PAGE
        self.readback_threads = min(self.readback_threads, self.tune_limit)
        self.tune_sample = self.tune_point()
        for block in self.allocations:
            self.cold.send(op='verify', threads=self.readback_threads)
            last = 0
            by_type = [0]*MIX_PAGES
            last_wall = [0]*len(STAGES)
            last_cpu = [0]*len(STAGES)
            last_faults = [0, 0]
            while True:
                msg = self.receive(self.cold)
                if 'processed' in msg:
                    processed = msg['processed']
                    counts = msg.get('by_type')
                    wall, cpu, faults = (msg.get(k) for k in ('wall_ns', 'cpu_ns', 'faults'))
                    lanes = msg.get('lanes')
                    def valid(values, previous):
                        return (isinstance(values, list) and len(values) == len(previous)
                                and all(type(a) is int and a >= b for a,b in zip(values, previous)))
                    if (type(processed) is not int or not last < processed <= block or processed % PAGE
                            or msg.get('pages') != processed//PAGE or msg.get('discarded') != processed
                            or lanes != min(self.readback_threads, block//PAGE)
                            or not valid(counts, by_type) or sum(counts)*PAGE != processed
                            or any(x > block//MIX_BYTES for x in counts)
                            or not valid(wall, last_wall) or not valid(cpu, last_cpu)
                            or not valid(faults, last_faults)):
                        raise Failure(f'Invalid parallel page progress: {msg}')
                    delta = processed-last
                    self.accessed += delta
                    self.pages_modified += delta//PAGE
                    self.discarded += delta
                    self.verified += delta
                    self.readback_active = lanes
                    for kind in range(MIX_PAGES):
                        self.discarded_by_type[kind] += (counts[kind]-by_type[kind])*PAGE
                    for i in range(len(STAGES)):
                        self.stage_wall[i] += wall[i]-last_wall[i]
                        self.stage_cpu[i] += cpu[i]-last_cpu[i]
                    for i in range(2):
                        self.readback_faults[i] += faults[i]-last_faults[i]
                    by_type, last_wall, last_cpu, last_faults = counts, wall, cpu, faults
                    self.last_progress = time.monotonic()
                    last = processed
                    continue
                if msg.get('match') is not True or msg.get('verified') != block or last != block or msg.get('pages') != block//PAGE:
                    raise Failure(f'Data integrity error or invalid verification response: {msg}')
                break
            self.tune_readback(block)
        self.readback_active = 0
        s = self.tick()
        if self.verified != self.total or self.accessed != self.total or self.discarded != self.total:
            raise Failure('Verified/accessed byte count does not match allocation')
        if s['reads'] <= before:
            raise Inconclusive('All checksums match, but no new backing-device reads observed')
        say(f'PASS READBACK: all SHA-256 checks passed; {self.pages_modified} pages '
            f'modified/restored/discarded; backing reads +{(s["reads"]-before)/256:.1f} MiB.')

    def cleanup(self):
        say('CLEANUP: terminating only transient test units; no global swapoff.')
        errors = []
        for worker in reversed(self.workers):
            try:
                worker.stop()
            except Exception as e:
                errors.append(str(e))
        registered = {w.unit for w in self.workers}
        for unit in self.units:
            if unit not in registered:
                try:
                    result = run('systemctl', 'stop', unit, timeout=15, check=False)
                    if result.returncode and 'not loaded' not in result.stderr.lower():
                        errors.append(result.stderr.strip())
                except Exception as e:
                    errors.append(str(e))
        if errors:
            say('Cleanup needs attention: '+'; '.join(errors))
            return False
        say('Transient test units stopped.')
        return True

    def execute(self):
        code = 1
        try:
            self.preflight()
            for name, function in [('NORMAL', self.normal), ('EMERGENCY', self.emergency),
                                   ('READBACK', self.readback)]:
                phase_started = time.monotonic()
                phase_baseline = snapshot()
                try:
                    function()
                    self.results[name] = 'PASS'
                except Inconclusive as e:
                    self.results[name] = 'INCONCLUSIVE: '+str(e)
                    say(self.results[name])
                    # A resource-limit/timeout result is not a service failure.
                    # Stop on low available RAM; do not escalate an unsafe workload.
                    if 'headroom' in str(e):
                        break
                except Exception as e:
                    self.results[name] = 'FAIL: '+str(e)
                    raise
                finally:
                    try:
                        end = snapshot()
                        self.phase_evidence[name] = (time.monotonic()-phase_started,
                            (end['writes']-phase_baseline['writes'])/256,
                            (end['reads']-phase_baseline['reads'])/256)
                    except Exception as e:
                        say('Phase statistics unavailable: '+str(e))
            code = 0 if all(self.results.get(x) == 'PASS' for x in ('NORMAL','EMERGENCY','READBACK')) else 2
        except Inconclusive as e:
            say('INCONCLUSIVE: '+str(e))
            code = 2
        except KeyboardInterrupt:
            say('INTERRUPTED: stopping test.')
            code = 130
        except Exception as e:
            say('FAIL: '+str(e))
            code = 1
        finally:
            if not self.cleanup():
                code = 1
            emit('\nFINAL RESULTS | W+/R+ in MiB, phase deltas')
            emit('Phase      | Result       |     Time s |         W+ |         R+')
            emit('-'*65)
            for name in ('NORMAL','EMERGENCY','READBACK'):
                result = self.results.get(name, 'NOT RUN')
                metrics = self.phase_evidence.get(name)
                cols = (' | '.join(f'{x:10.1f}' for x in metrics) if metrics else
                        '         - |          - |          -')
                emit(f'{name:10} | {result.split(":",1)[0]:12} | {cols}')
                if ':' in result:
                    say(f'{name} detail: {result.split(":",1)[1].strip()}')
            emit(f'Accessed: {self.accessed/MIB:.1f}/{self.total/MIB:.1f} MiB  '
                 f'Verified: {self.verified/MIB:.1f} MiB')
            emit(f'Pages modified, restored and discarded: {self.pages_modified}')
            emit('COLD WORKLOAD | exact thirds; MiB (hot worker excluded)')
            emit('Page type          | Allocated  | Discarded')
            emit('-'*45)
            for kind, name in enumerate(('Repeated pattern', 'Random', 'Same-element')):
                emit(f'{name:18} | {self.total/3/MIB:10.2f} | {self.discarded_by_type[kind]/MIB:9.2f}')
            emit(f'Discarded: {self.discarded/MIB:.1f} MiB')
            if self.pages_modified:
                emit('READBACK TIMING | summed per-thread stage times, not elapsed phase time')
                emit('Stage       | Wall s sum | CPU s sum | Mean wall us/page')
                emit('-'*58)
                for i, stage in enumerate(STAGES):
                    emit(f'{stage:11} | {self.stage_wall[i]/1e9:10.3f} | {self.stage_cpu[i]/1e9:9.3f} | {self.stage_wall[i]/1000/self.pages_modified:17.2f}')
                emit(f'Last thread target: {self.readback_threads}')
                emit(f'Memory mapping resolves (minor): {self.readback_faults[0]}')
                emit(f'Page retrieval events (major): {self.readback_faults[1]}')
                emit('Page events are normal VM operations, not data integrity or storage errors.')
                best_text = f'{self.tune_best_rate:.2f} MiB/s' if self.tune_best_rate is not None else 'unavailable'
                emit(f'Adaptive tuning: {self.tune_state}; recent best verified rate: {best_text}')
                emit('TUNING HISTORY | all valid measurement windows, duration-weighted')
                emit('Threads | Windows | Seconds | Done MiB/s | CPU busy%')
                for threads, windows in sorted(self.tune_history.items()):
                    seconds = sum(dt for _,dt,_ in windows)
                    rate = sum(r*dt for r,dt,_ in windows)/seconds
                    cpu = sum(p*dt for _,dt,p in windows)/seconds
                    emit(f'{threads:7} | {len(windows):7} | {seconds:7.1f} | {rate:10.2f} | {cpu:9.1f}')
                emit('See TUNE log lines for concurrency, busy CPU and separate backing/verified rates.')
                emit('Retrieve wall vs CPU includes page faults, I/O, scheduling and kernel work; not isolated NVMe or decompression time.')
                emit('CSV contains interval backing read latency, queue depth and system CPU steal when available.')
            emit('COMPRESSION | largest sampled logical volume before/no backing entries')
            if self.compression_peak is not None:
                c = self.compression_peak
                ratio, payload_saving, resident_saving = compression(c)
                emit(f'Logical: {c["original"]/MIB:.2f} MiB | Payload: {c["compressed"]/MIB:.2f} MiB | RAM: {c["used"]/MIB:.2f} MiB')
                if ratio is not None:
                    emit(f'Payload ratio: {ratio:.2f}:1 | Payload saved: {payload_saving:.2f}% | RAM saved: {resident_saving:.2f}%')
                else:
                    emit(f'Payload ratio: undefined (zero payload) | Payload saved: {payload_saving:.2f}% | RAM saved: {resident_saving:.2f}%')
                emit(f'Same-element pages: {c["same_pages"]} | Incompressible pages: {c["huge_pages"]}')
                logical, share, non_same = same_metrics(c)
                if share is not None:
                    emit(f'Same-element logical volume: {logical/MIB:.2f} MiB ({share:.2f}% of device logical data)')
                if non_same is not None:
                    emit(f'Payload ratio excluding same-element logical pages: {non_same:.2f}:1')
                emit('Same-element entries use no separate compressed payload; metadata overhead remains.')
            else:
                emit('No comparable sample; cannot report a compression ratio.')
            emit('Compression statistics are device-wide, not an isolated per-class codec benchmark.')
            emit('Same-element logical volume is not measured physical RAM savings; backing I/O is separate.')
            emit('RESIDENT COMPRESSION | largest consistent sampled resident logical volume')
            if self.resident_peak is not None:
                s = self.resident_peak
                logical, ratio, non_same, saved, ram_saved, same_pct = resident_metrics(s)
                emit(f'Resident logical={logical/MIB:.2f} MiB | backing={s["backing"]/256:.2f} MiB | payload={s["compressed"]/MIB:.2f} MiB')
                emit(f'Resident payload ratio={ratio:.2f}:1 | payload saved={saved:.2f}% | RAM saved={ram_saved:.2f}%')
                emit(f'Excluding same-element={non_same:.2f}:1 | same-element resident logical share={same_pct:.2f}%')
            else:
                emit('No consistent resident compression sample.')
            emit('Live resident ratios subtract full backing slot bytes; inconsistent samples are blank.')
            emit('CSV retains legacy no-backing ratios and adds separate live resident/capacity columns.')
            if hasattr(self, 'base'):
                try:
                    s = snapshot()
                    say(f'TOTAL: backing writes +{(s["writes"]-self.base["writes"])/256:.1f} MiB; '
                        f'reads +{(s["reads"]-self.base["reads"])/256:.1f} MiB; '
                        f'final resident={s["used"]/MIB:.1f} MiB; '
                        f'verified={self.verified/MIB:.1f} MiB.')
                except Exception as e:
                    say('Final statistics unavailable: '+str(e))
            say(f'Exit status {code} (0=all pass, 1=failure, 2=inconclusive, 130=interrupted)')
        return code


def controller():
    global LOG, CSV
    # Exclusive creation avoids overwriting logs, even after rapid reruns.
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    stem = Path.cwd()/f'test_zram_{stamp}_{os.getpid()}'
    log_path = stem.with_suffix('.log')
    csv_path = stem.with_suffix('.csv')
    try:
        with log_path.open('x', buffering=1, encoding='utf-8') as log_file:
            LOG = log_file
            try:
                with csv_path.open('x', buffering=1, encoding='utf-8', newline='') as csv_file:
                    CSV = csv.DictWriter(csv_file, fieldnames=CSV_FIELDS)
                    CSV.writeheader()
                    say(f'Text log: {log_path}')
                    say(f'Metrics CSV: {csv_path}')
                    return Test().execute()
            finally:
                LOG = CSV = None
    except OSError as e:
        print(f'Logging or I/O error: {e}', file=sys.stderr, flush=True)
        return 1


def interrupt(signum, frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    if sys.argv[1:] == ['--cold-worker']:
        cold_worker()
    elif len(sys.argv) == 3 and sys.argv[1] == '--hot-worker':
        hot_worker(int(sys.argv[2]))
    elif len(sys.argv) == 1:
        signal.signal(signal.SIGTERM, interrupt)
        signal.signal(signal.SIGHUP, interrupt)
        sys.exit(controller())
    else:
        sys.exit('Usage: sudo python3 test_zram.py')
