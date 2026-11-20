#!/usr/bin/env python3
"""Sequential test of home_server's zram-pressure.service. Disposable VM only.
Run: sudo python3 test_zram.py
Creates timestamped text and CSV logs in the current working directory.
No package installation, service changes, swapoff, or writes to ZRAM sysfs.
Internal worker modes are launched only by the controller in transient units.
"""
import csv
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
AGE_SECONDS = 65
POLL = 1.0
PAGE = os.sysconf('SC_PAGE_SIZE')
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
              'orig_data_bytes', 'compr_data_bytes', 'same_pages', 'huge_pages',
              'huge_pages_since', 'compression_ratio_no_backing',
              'payload_savings_pct_no_backing', 'resident_savings_pct_no_backing',
              'readback_idle_s')


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
    # orig_data_size may include entries already written back, whereas
    # compr_data_size is resident payload. Only compute compression ratios
    # when there are no backing entries and no intervening backing writes.
    comparable = backing == bd_before[0] == 0 and writes == bd_before[2]
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
                same_pages=mm[5] if len(mm)>5 else None,
                huge_pages=mm[7] if len(mm)>7 else None,
                huge_pages_since=mm[8] if len(mm)>8 else None)


def compression(s):
    if not s.get('comparable') or not s['original']:
        return None, None, None
    o, c, u = s['original'], s['compressed'], s['used']
    return (o/c if c else None, 100*(1-c/o), 100*(1-u/o))


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


def cold_worker():
    """Equal mixed pages, FIFO verification, immediate per-page discard."""
    blocks = []
    def reply(**data):
        print('ZTEST '+json.dumps(data), flush=True)
    reply(ready=True)
    for line in sys.stdin:
        command = json.loads(line)
        if command['op'] == 'alloc':
            n = command['n']
            if n <= 0 or n % (2*PAGE):
                raise ValueError('Cold allocations must contain an even number of pages')
            m = private_mapping(n)
            # Repeated non-uniform 64-byte pattern; not a same-element page.
            pattern = bytes(range(64))
            repeated = (pattern*((PAGE+len(pattern)-1)//len(pattern)))[:PAGE]
            digests = bytearray()
            try:
                for i in range(n//PAGE):
                    page = repeated if i % 2 == 0 else os.urandom(PAGE)
                    m[i*PAGE:(i+1)*PAGE] = page
                    digests.extend(hashlib.sha256(page).digest())
                del page
                m.madvise(MADV_COLD)
                m.madvise(MADV_PAGEOUT)
                blocks.append((m, digests, n))
            except BaseException:
                m.close()
                raise
            reply(allocated=n, compressible=n//2, random=n//2)
        elif command['op'] == 'verify':
            if not blocks:
                reply(done=True)
                continue
            m, digests, n = blocks.pop(0)
            last_report = time.monotonic()
            for i, offset in enumerate(range(0, n, PAGE)):
                original = m[offset:offset+PAGE]
                if hashlib.sha256(original).digest() != digests[i*32:(i+1)*32]:
                    reply(error=f'Page checksum mismatch at offset {offset}')
                    m.close()
                    return
                first = original[0]
                m[offset] = first ^ 1
                if m[offset] != (first ^ 1):
                    raise RuntimeError(f'Page modification failed at {offset}')
                m[offset] = first
                if m[offset] != first:
                    raise RuntimeError(f'Page restoration failed at {offset}')
                # The mapping is private anonymous memory, and this specific
                # page is verified. Discard it, not the rest of the mapping.
                m.madvise(MADV_DONTNEED, offset, PAGE)
                del original
                processed = offset+PAGE
                now = time.monotonic()
                if processed % READBACK_PROGRESS == 0 or processed == n or now-last_report >= 1:
                    reply(processed=processed, pages=i+1, discarded=processed)
                    last_report = now
            m.close()
            reply(verified=n, match=True, pages=n//PAGE)
        elif command['op'] == 'exit':
            break
        else:
            raise ValueError('Invalid internal command')
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
        self.verified = 0
        self.accessed = 0
        self.pages_modified = 0
        self.discarded = 0
        self.compression_peak = None
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
        ram = meminfo()['MemTotal']
        # Reserve other system memory and swap. Bounded test-only allocation.
        self.reserve = max(128*MIB, ram//16)
        self.resident = min(256*MIB, s['available']//4, ram//8)
        self.hot_size = min(96*MIB, max(16*MIB, s['limit']//25))//PAGE*PAGE
        self.hot_max = self.hot_size+48*MIB
        self.budget = min(s['swap_free']*85//100, s['limit']*3)
        self.budget = self.budget//(2*PAGE)*(2*PAGE)
        self.chunk = min(32*MIB, max(PAGE, self.resident//8))//PAGE*PAGE
        if s['occupancy'] >= 70:
            raise Inconclusive('Baseline occupancy >=70%; use a quiet VM')
        if self.resident < 64*MIB or s['available'] < self.reserve+self.resident+self.hot_max:
            raise Inconclusive('Insufficient available RAM for bounded worker cgroups')
        if self.budget < s['limit']:
            raise Inconclusive('Insufficient free logical swap for a meaningful run')
        say(f'Kernel={os.uname().release}; backing={backing}; '
            f'RAM={ram/MIB:.0f} MiB; resident limit={s["limit"]/MIB:.0f} MiB')
        say(f'Cold allocation cap={self.budget/MIB:.0f} MiB; cold RAM cap={self.resident/MIB:.0f} MiB; '
            f'hot working set={self.hot_size/MIB:.0f} MiB; reserve={self.reserve/MIB:.0f} MiB')
        say('WARNING: deliberate memory/swap pressure and SSD writes; disposable VM only.')
        # Controller deadlines/watchdog govern the cold worker, not systemd.
        say('Cold workload: exactly 50% repeated-pattern pages, 50% random pages; hot worker separately random.')
        self.cold = Worker(self.units, 'cold', self.resident, self.budget, runtime=None)
        self.workers.append(self.cold)
        if not self.receive(self.cold).get('ready'):
            raise Failure('Cold worker did not initialize')

    def tick(self):
        if self.deadline is not None and time.monotonic() >= self.deadline:
            raise Inconclusive(f'{self.phase} timed out')
        s = snapshot()
        if self.total and s['comparable'] and s['original'] > self.base['original'] and (self.compression_peak is None or s['original'] > self.compression_peak['original']):
            self.compression_peak = dict(s)
        if s['limit'] != self.base['limit']:
            raise Failure('ZRAM resident limit changed during test')
        if s['errors'] != self.base['errors']:
            raise Failure(f'ZRAM I/O error counters changed: {self.base["errors"]} -> {s["errors"]}')
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

    def display(self, s):
        now = time.monotonic()
        remaining = max(0, self.deadline-now) if self.deadline is not None else None
        idle = max(0, now-self.last_progress) if self.phase == 'READBACK' and self.last_progress is not None else None
        ratio, payload_saving, resident_saving = compression(s)
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
                emit('   Time |   Read+ | Discarded |   Swap |   MiB/s |  ETA s | Idle s')
                emit('-'*69)
            emit(f'{now-START:7.1f} | {reads:7.1f} | {self.discarded/MIB:9.1f} | '
                 f'{s["swap_used"]/MIB:6.1f} | {rate:7.2f} | {eta_text:>6} | {idle:6.0f}')
        else:
            if header:
                emit('   Time | Occ% |  PSI% |   ZRAM |   Swap |     W+ | Ratio | Left')
                emit('-'*69)
            ratio_text = f'{ratio:.2f}' if ratio is not None else '-'
            emit(f'{now-START:7.1f} | {s["occupancy"]:4} | {s["psi"]:5.2f} | '
                 f'{s["used"]/MIB:6.1f} | {s["swap_used"]/MIB:6.1f} | '
                 f'{writes:6.1f} | {ratio_text:>5} | {remaining:4.0f}')
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
                compressible_allocated_bytes=self.total//2, random_allocated_bytes=self.total//2,
                orig_data_bytes=s['original'], compr_data_bytes=s['compressed'],
                same_pages=s['same_pages'], huge_pages=s['huge_pages'], huge_pages_since=s['huge_pages_since'],
                compression_ratio_no_backing=ratio, payload_savings_pct_no_backing=payload_saving,
                resident_savings_pct_no_backing=resident_saving, readback_idle_s=idle))

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
        n = min(self.chunk, max(2*PAGE, gap//2), self.budget-self.total,
                max(0, s['swap_free']-self.hot_size-32*MIB))//(2*PAGE)*(2*PAGE)
        if n <= 0:
            return False
        self.cold.send(op='alloc', n=n)
        msg = self.receive(self.cold)
        if msg.get('allocated') != n or msg.get('compressible') != n//2 or msg.get('random') != n//2:
            raise Failure(f'Unexpected allocation reply: {msg}')
        self.total += n
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
                raise Inconclusive('Allocation budget exhausted before normal prefill')
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

    def readback(self):
        self.phase = 'READBACK'
        self.readback_started = self.last_progress = time.monotonic()
        self.deadline = None
        before = snapshot()['reads']
        say(f'3/3 READBACK: oldest first; access, flip/restore one bit per page, '
            f'verify SHA-256 and immediately discard all {self.total/MIB:.1f} MiB.')
        say(f'No overall readback deadline; no-progress timeout {READBACK_STALL_SECONDS}s.')
        if not self.total:
            raise Inconclusive('No cold data allocated')
        while self.verified < self.total:
            self.cold.send(op='verify')
            last = 0
            while True:
                msg = self.receive(self.cold)
                if 'processed' in msg:
                    processed = msg['processed']
                    if not isinstance(processed, int) or not last < processed <= self.total-self.verified+last or processed % PAGE or msg.get('pages') != processed//PAGE or msg.get('discarded') != processed:
                        raise Failure(f'Invalid page progress: {msg}')
                    self.accessed += processed-last
                    self.pages_modified += (processed-last)//PAGE
                    self.discarded += processed-last
                    self.verified += processed-last
                    self.last_progress = time.monotonic()
                    last = processed
                    continue
                if msg.get('match') is not True or msg.get('verified') != last or not last or msg.get('pages') != last//PAGE:
                    raise Failure(f'Cold data checksum mismatch or invalid response: {msg}')
                break
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
            emit(f'Cold allocation: compressible={self.total/2/MIB:.1f} MiB; random={self.total/2/MIB:.1f} MiB')
            emit(f'Discarded: {self.discarded/MIB:.1f} MiB')
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
            else:
                emit('No comparable sample; cannot report a compression ratio.')
            emit('Compression statistics are device-wide, not per data type; backing I/O is separate.')
            emit('Ratio is suppressed when backing entries exist. See CSV for all raw counters.')
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
