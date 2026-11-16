# 03 — Recreate the complete ZRAM installer profile, step by step

**Goal:** reconstruct the exact source of this **destructive, optional Debian Installer feature**, including selection, confirmation, native GPT conversion and ZSTD ZRAM writeback configuration. Do not copy the following installer commands into a normal Debian terminal. For that use [05 — Standalone ZRAM](../05_zram_writeback/README.md) with ordinary full-system tools.

**Safety:** this handler can zero the first **1 MiB of a GPT partition**. Only test on a disposable virtual disk. No live VM or physical partition test has been completed for the current native-udeb refactor.

## Step 1 — Complete the prerequisites

1. Build the Simple-CDD project in [01](01_custom_cdd_preparation.md).
2. Create the shared code and profile rules in [00](00_profile_construction.md).
3. Create the native early/late selection UI and dispatcher in [05](05_base_installation.md).
4. Also create the **independently selectable Linux 7.x profile** from [09](09_ensure_7x_kernel.md). ZRAM may not run unless that profile was separately selected and successfully completed.

The build-only `profiles/installer-media.udebs` already includes `parted-udeb` and `util-linux-udeb` from [01](01_custom_cdd_preparation.md); they provide native commands in the installer, not the installed target. The default Debconf template in [05](05_base_installation.md) supplies the separate default-No ZRAM destructive and swapoff questions.

Work inside `99_custom_netintst/my-cdd/`, on a test branch or scratch copy.

## Step 2 — Know exactly which files make up the feature

| File to create | Reason |
| --- | --- |
| `profiles/zram-writeback.description` | Text of the opt-in ZRAM checkbox. |
| `profiles/zram-writeback.extra` | All required sources and generator/monitor assets to stage on the installer ISO. |
| `profiles/zram-writeback.postinst` | Executable completion-marker verifier (not a second partition conversion). |
| `installer/profile-zram.sh` | The complete selected-only handler: confirmation, RAM/swapoff checks, bounded erase, native Parted, fstab and target provisioning. |
| `installer/zram-selection.sh` | The complete installer-native GPT/sysfs/blkid candidate discovery, identity validation, mount/holder checks and fstab preparation. |
| `scripts/zram-generator.conf.template` | ZSTD/ZRAM sizing and writeback config; dynamically replaced PARTUUID placeholders. |
| `scripts/10-compressed-writeback.conf` | Systemd drop-in controlling compressed writeback setup. |
| `scripts/zram-pressure.sh` | Complete script monitoring memory pressure and issuing writeback operations. |
| `scripts/zram-pressure.service` | Systemd service to supervise and restart the pressure monitor. |
| `scripts/90-zram-swappiness.conf` | Swappiness setting applicable only to the explicitly selected ZRAM feature. |

All **ten** source/configuration files are included in full below. You do not need to invent any missing functions or generator scripts.

## Step 3 — Create each file

Prepare the source folders:

~~~sh
mkdir -p profiles installer scripts
~~~

This creates project directories only, not partitions.

**1. Create `profiles/zram-writeback.description`.** Text of the opt-in ZRAM checkbox.

~~~sh
nano profiles/zram-writeback.description
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**2. Create `profiles/zram-writeback.extra`.** All required sources and generator/monitor assets to stage on the installer ISO.

~~~sh
nano profiles/zram-writeback.extra
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**3. Create `profiles/zram-writeback.postinst`.** Executable completion-marker verifier (not a second partition conversion).

~~~sh
nano profiles/zram-writeback.postinst
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**4. Create `installer/profile-zram.sh`.** The complete selected-only handler: confirmation, RAM/swapoff checks, bounded erase, native Parted, fstab and target provisioning.

~~~sh
nano installer/profile-zram.sh
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**5. Create `installer/zram-selection.sh`.** The complete installer-native GPT/sysfs/blkid candidate discovery, identity validation, mount/holder checks and fstab preparation.

~~~sh
nano installer/zram-selection.sh
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**6. Create `scripts/zram-generator.conf.template`.** ZSTD/ZRAM sizing and writeback config; dynamically replaced PARTUUID placeholders.

~~~sh
nano scripts/zram-generator.conf.template
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**7. Create `scripts/10-compressed-writeback.conf`.** Systemd drop-in controlling compressed writeback setup.

~~~sh
nano scripts/10-compressed-writeback.conf
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**8. Create `scripts/zram-pressure.sh`.** Complete script monitoring memory pressure and issuing writeback operations.

~~~sh
nano scripts/zram-pressure.sh
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**9. Create `scripts/zram-pressure.service`.** Systemd service to supervise and restart the pressure monitor.

~~~sh
nano scripts/zram-pressure.service
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**10. Create `scripts/90-zram-swappiness.conf`.** Swappiness setting applicable only to the explicitly selected ZRAM feature.

~~~sh
nano scripts/90-zram-swappiness.conf
~~~

This opens a source file without executing it. Expand the **complete listing for that same path below**, copy every line, save with Ctrl+O, Enter, and exit with Ctrl+X. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.


Make the completion verifier executable:

~~~sh
chmod +x profiles/zram-writeback.postinst
~~~

The main `installer/profile-zram.sh` handler is **sourced**; it is never invoked as a standalone host program.

## Step 4 — Understand how the complete code fits together

1. **Profile consent is not disk consent.** `simple-cdd.conf` offers the optional `zram-writeback` checkbox, but the shared selector rejects it without independently selected `ensure-7x-kernel`. The dispatcher maps the ZRAM name to `profile_zram()`.
2. **Installer-native tools:** the handler loads `parted-udeb` / `util-linux-udeb` when absent, checks native BusyBox `dd` and `swapoff` applets, and sources `zram-selection.sh`.
3. **Candidate discovery:** the selection helper uses `/sys/class/block` and native `blkid -p -o export` to inspect GPT partition number, parent disk, GUID type and **actual PARTUUID**. It accepts GPT swap-type partitions, plus already prepared raw partitions named `zram-writeback`. It rejects duplicate identities, mounts and block-device holders.
4. **Automatic choice is narrowly limited:** exactly one suitable conventional swap reference in the new target's `/target/etc/fstab` may be selected automatically. Otherwise the native Debconf chooser presents the exact candidates and initially offers **Stop**.
5. **Independent destructive approval:** after selecting a candidate, the handler shows the exact partition device, parent disk, size, PARTUUID and planned **first-1-MiB erase**. The default is **No**.
6. **Active swap safety:** used swap is identified in `/proc/swaps`. The handler requires enough available RAM for the used pages **plus a reserve**, asks another default-No confirmation for targeted `swapoff`, and revalidates the partition before touching it.
7. **fstab preparation:** before writes, the helper prepares removal of only that partition's conventional swap entry. It must not delete unrelated root, EFI or NAS mounts.
8. **Bounded signature erase:** once all checks pass, the handler runs BusyBox `dd` with `bs=4096 count=256` against the **verified partition**, not its parent disk. That writes exactly **1 MiB**.
9. **GPT conversion without recreation:** native Parted changes that partition's **type** to standard Linux data (gdisk 8300, GUID `0FC63DAF-8483-4772-8E79-3D69D8477DE4`) and its **name** to `zram-writeback`. It does **not** format a filesystem, delete the partition or hardcode the machine's PARTUUID. Post-write checks must confirm correct identity and no residual swap signature.
10. **Target provisioning:** an atomically staged `fstab` is installed; the user approves installing `systemd-zram-generator`; both template `YOUR_PARTUUID` placeholders are replaced with the **actual detected PARTUUID**. The generator, writeback overrides, pressure monitor and swappiness file are installed under `/target`; GRUB is updated for `zswap.enabled=0`.

## Step 5 — Check copied source before any disk operation

~~~sh
sh -n installer/profile-zram.sh
~~~

This syntax-checks the main handler without running it.

~~~sh
sh -n installer/zram-selection.sh
~~~

This checks the GPT selection helper without touching a disk.

~~~sh
sh -n scripts/zram-pressure.sh
~~~

This checks the independent pressure-monitor script. For exact-copy verification, `git hash-object <file>` prints the file's Git blob SHA; compare it against its listing heading.

Build the complete source with `./build.sh` **only when all shared and selected profile files exist**. The complete code remains **unverified in a live installer**; use a throwaway VM to test every approval and cancellation, exact-device selection, swapoff, GPT conversion, first boot, writeback counters and emergency recovery.

## The complete ten source files

**Expand each listing below and paste the full contents into the exact path above.** These are the actual, fully intact files from the recorded repository revision, not fragments or illustrative pseudocode. You can read the steps above without scrolling through hundreds of lines of code.
<details>
<summary><strong>profiles/zram-writeback.description</strong> — complete file; 1 lines; original blob <code>df57e419caae6cd3ab80da467bcfb3bdbfb55444</code></summary>

````text
ZSTD ZRAM writeback; confirmed raw GPT backing, requires Linux 7.x
````

</details>

<details>
<summary><strong>profiles/zram-writeback.extra</strong> — complete file; 8 lines; original blob <code>89ae2d962bd35fbb48f692c44f42b20fe6469c63</code></summary>

````text
# zram-writeback: source assets copied by Simple-CDD (not automatically installed).
installer/profile-zram.sh
installer/zram-selection.sh
scripts/zram-generator.conf.template
scripts/10-compressed-writeback.conf
scripts/zram-pressure.sh
scripts/zram-pressure.service
scripts/90-zram-swappiness.conf
````

</details>

<details>
<summary><strong>profiles/zram-writeback.postinst</strong> — complete file; 11 lines; original blob <code>f1b1bba87c3d2a53cc84ee2a9658348287a57d5f</code></summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/zram-writeback"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'zram-writeback'
    exit 1
fi
````

</details>

<details>
<summary><strong>installer/profile-zram.sh</strong> — complete file; 180 lines; original blob <code>461b35a6a3d1ba53cf2e972f551109a7f4aae3bb</code></summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_zram() {
    [ -f "$LOG_DIR/my-cdd-completed/ensure-7x-kernel" ] ||
        fatal 'ZRAM cannot run without the separately completed Ensure 7.x kernel profile'
    [ -r "$MEDIA/zram-generator.conf.template" ] ||
        fatal 'Original ZRAM generator source missing'
    [ -r "$MEDIA/zram-selection.sh" ] ||
        fatal 'Installer ZRAM selection helper missing'
    . "$MEDIA/zram-selection.sh"
    # The installer is a minimal udeb environment. The official parted-udeb
    # supplies the installer-native GPT editing CLI and matching udeb libraries.
    # Simple-CDD stages it via the build-only installer-media.udebs profile;
    # anna-install loads it only for an explicitly chosen ZRAM profile.
    # Do not copy normal target binaries or libraries into Debian Installer.
    if ! command -v parted >/dev/null 2>&1; then
        command -v anna-install >/dev/null 2>&1 ||
            fatal 'Native Debian Installer anna-install is unavailable for parted-udeb'
        capture anna-install parted-udeb ||
            fatal 'Could not load official parted-udeb into Debian Installer'
    fi
    command -v parted >/dev/null 2>&1 ||
        fatal 'Official parted-udeb did not provide a usable parted command'
    # Load installer-native blkid from util-linux-udeb when absent.
    if ! command -v blkid >/dev/null 2>&1; then
        capture anna-install util-linux-udeb ||
            fatal 'Could not load official util-linux-udeb into Debian Installer'
    fi
    # Check all remaining installer utilities before a destructive conversion.
    zram_check_utilities
    zram_collect_candidates
    zram_choose_candidate
    uuid=$zram_uuid
    device=$zram_device
    size=$zram_size
    former_uuid="$(zram_blkid -s UUID -o value "$device" 2>/dev/null || true)"
    former_label="$(zram_blkid -s LABEL -o value "$device" 2>/dev/null || true)"
    zram_prepare_fstab

    # The automatically detected partition still requires exactly the same
    # destructive confirmation as a manually selected partition. A partition
    # shared with another OS loses its conventional swap identity.
    db_subst my-cdd/zram-destructive MYCDD_PARTITION "$device" ||
        fatal 'Unable to show partition path for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_PARTUUID "$uuid" ||
        fatal 'Unable to show exact PARTUUID for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_SIZE "$size" ||
        fatal 'Unable to show partition capacity for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_DISK "$disk" ||
        fatal 'Unable to show selected parent disk'
    db_subst my-cdd/zram-destructive MYCDD_SELECTION "$zram_selection" ||
        fatal 'Unable to show selection provenance'
    yes_no my-cdd/zram-destructive ||
        fatal 'User declined destructive ZRAM backing conversion'

    # Debian Installer may itself activate even newly created swap. Leave
    # unrelated swap devices completely untouched; never use swapoff -a.
    zram_read_active_swap
    if [ -n "$active_used" ]; then
        available_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
        total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
        case "$available_kb:$total_kb" in
            *[!0-9:]*|:*|*:) fatal 'Cannot assess installer memory pressure for swapoff' ;;
        esac
        if [ -r /proc/pressure/memory ]; then
            log "Installer memory PSI before any swapoff: $(head -n 2 /proc/pressure/memory | tr '\n' ';')"
        fi
        reserve_kb=$((total_kb / 8))
        [ "$reserve_kb" -ge 262144 ] || reserve_kb=262144
        used_kb=$((active_used / 1024 + 1))
        [ "$available_kb" -gt "$((used_kb + reserve_kb))" ] ||
            fatal 'RAM cannot cover selected swap usage plus a safety reserve; no swapoff attempted'
        db_subst my-cdd/zram-swapoff MYCDD_PARTITION "$device" ||
            fatal 'Cannot show exact swapoff target'
        db_subst my-cdd/zram-swapoff MYCDD_USED "$active_used" ||
            fatal 'Cannot show selected swap usage'
        yes_no my-cdd/zram-swapoff ||
            fatal 'Targeted swapoff was not separately approved'
        # Re-evaluate memory and identity immediately before swapoff, too.
        zram_validate_candidate
        zram_read_active_swap
        if [ -n "$active_used" ]; then
            available_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
            case "$available_kb" in ''|*[!0-9]*) fatal 'RAM check failed immediately before swapoff' ;; esac
            used_kb=$((active_used / 1024 + 1))
            [ "$available_kb" -gt "$((used_kb + reserve_kb))" ] ||
                fatal 'Insufficient remaining RAM for a safe targeted swapoff'
            capture busybox swapoff "$device" ||
                fatal 'Targeted swapoff failed; GPT and signatures left unchanged'
        fi
        zram_read_active_swap
        [ -z "$active_used" ] ||
            fatal 'Selected partition still active after targeted swapoff'
    fi
    zram_validate_candidate
    zram_read_active_swap
    [ -z "$active_used" ] ||
        fatal 'Selected backing was reactivated as swap before conversion'

    # Write only the approved partition's first 1 MiB, never its parent disk.
    # The GPT layout and PARTUUID are preserved; no filesystem is created.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after verification; conversion stopped'
    log "USER APPROVED CONVERSION: $device, PARTUUID=$uuid, size=$size"
    capture busybox dd if=/dev/zero of="$device" bs=4096 count=256 conv=notrunc,fsync ||
        fatal 'Could not erase swap signature from the confirmed backing partition'
    capture parted -s "$disk" type "$partn" "$ZRAM_DATA_GUID" ||
        fatal 'Could not change only the confirmed GPT partition type'
    capture parted -s "$disk" name "$partn" zram-writeback ||
        fatal 'Could not set confirmed GPT PARTLABEL'
    zram_partition_info "$device" ||
        fatal 'Cannot re-probe converted GPT partition'
    [ "$zi_type" = "$ZRAM_DATA_GUID" ] && [ "$zi_label" = zram-writeback ] ||
        fatal 'Converted backing GPT type or name is incorrect'
    [ -z "$zi_signature" ] ||
        fatal 'Converted backing still has a detected filesystem/swap signature'
    [ "$zi_partuuid" = "$uuid" ] ||
        fatal 'PARTUUID unexpectedly changed without partition recreation'
    ! zram_is_mounted ||
        fatal 'Converted partition unexpectedly mounted'
    zram_read_active_swap
    [ -z "$active_used" ] ||
        fatal 'Converted raw backing is still conventional swap'
    # This exact filtered fstab was prepared before destructive conversion;
    # preserve every unrelated swap line and refuse residual aliases.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after conversion; manual repair is required'
    # Stage the verified fstab on the target filesystem, then replace it
    # atomically. A failed copy must not truncate the active target fstab.
    fstab_tmp="/target/etc/.fstab.my-cdd.$$"
    [ ! -e "$fstab_tmp" ] ||
        fatal 'Unexpected temporary target fstab path already exists'
    cp "$WORK/zram-safe-fstab" "$fstab_tmp" ||
        fatal 'Could not stage target fstab after partition conversion'
    chmod 644 "$fstab_tmp" ||
        fatal 'Could not set staged target fstab permissions'
    mv -f -- "$fstab_tmp" /target/etc/fstab ||
        fatal 'Could not atomically install the verified target fstab'
    awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}' \
        /target/etc/fstab > "$WORK/zram-residual-swaps"
    while IFS= read -r swap_ref; do
        if zram_ref_matches "$swap_ref" "$uuid" "$device" "$former_uuid" "$former_label"; then
            fatal 'Confirmed backing is still referenced as conventional swap'
        fi
    done < "$WORK/zram-residual-swaps"
    # No other ZRAM provisioning occurs until the partition conversion
    # (type, name, PARTUUID, signatures and active-swap state) has passed.

    review_install 'ZRAM generator package and all dependencies' systemd-zram-generator
    mkdir -p /target/etc/systemd/system/systemd-zram-setup@zram0.service.d \
        /target/etc/systemd/system /target/etc/sysctl.d /target/usr/local/sbin
    sed "s/YOUR_PARTUUID/$uuid/g" "$MEDIA/zram-generator.conf.template" > \
        /target/etc/systemd/zram-generator.conf
    [ "$(grep -o "$uuid" /target/etc/systemd/zram-generator.conf | wc -l)" -eq 2 ] &&
        ! grep -q YOUR_PARTUUID /target/etc/systemd/zram-generator.conf ||
        fatal 'ZRAM generator configuration contains unresolved or mismatched backing identity'
    cp "$MEDIA/10-compressed-writeback.conf" \
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/10-compressed-writeback.conf
    # Setup failure enters emergency, unlike a monitor failure.
    printf '[Unit]\nOnFailure=emergency.target\nOnFailureJobMode=replace-irreversibly\n' > \
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/20-failure-emergency.conf
    cp "$MEDIA/zram-pressure.sh" /target/usr/local/sbin/zram-pressure.sh
    chmod 755 /target/usr/local/sbin/zram-pressure.sh
    cp "$MEDIA/zram-pressure.service" /target/etc/systemd/system/zram-pressure.service
    cp "$MEDIA/90-zram-swappiness.conf" /target/etc/sysctl.d/90-zram-swappiness.conf
    # zswap must not intercept memory intended for zram.
    if ! grep -q 'zswap.enabled=0' /target/etc/default/grub; then
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ zswap.enabled=0"/' /target/etc/default/grub
    fi
    run_target update-grub
    run_target systemctl enable zram-pressure.service
    # Defense in depth: common preflight has already established recovery access
    # before any selected profile (including this partition conversion).
    capture in-target passwd -S root || fatal 'Cannot inspect emergency root account'
    grep -E '^root[[:space:]]+P[[:space:]]' "$WORK/output" >/dev/null ||
        fatal 'Separate local root password is not enabled for ZRAM emergency recovery'
    log "ZRAM raw backing: $device PARTUUID=$uuid size=$size; boot kernel/sysfs and generator require first-boot validation"
}

````

</details>

<details>
<summary><strong>installer/zram-selection.sh</strong> — complete file; 290 lines; original blob <code>80179568e48742b74e87c9645f69e9e4ebe7c07a</code></summary>

````sh
#!/bin/sh
# Native Debian Installer ZRAM tools; no target util-linux block commands.
# Standard GPT PARTITION TYPE GUIDs (not disk-specific PARTUUIDs):
#   Linux swap:                 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
#   Linux filesystem/data:      0FC63DAF-8483-4772-8E79-3D69D8477DE4 (gdisk 8300)
# The ZRAM backing remains raw/unformatted. GNU Parted's "type" command
# requires the GPT type GUID, whereas blkid reports it for eligibility checks.
ZRAM_SWAP_GUID=0657fd6d-a4ab-43c4-84e5-0933c84b4f4f
ZRAM_DATA_GUID=0fc63daf-8483-4772-8e79-3d69d8477de4

zram_blkid() { blkid "$@"; }

zram_check_utilities() {
    for utility in parted blkid busybox readlink cmp awk sed; do
        command -v "$utility" >/dev/null 2>&1 ||
            fatal "ZRAM requires unavailable Debian Installer utility: $utility"
    done
    for applet in dd swapoff; do
        busybox --list | grep -qx "$applet" ||
            fatal "ZRAM requires unavailable Debian Installer BusyBox applet: $applet"
    done
    [ -d /sys/class/block ] && [ -r /proc/swaps ] &&
        [ -r /proc/self/mountinfo ] && [ -d /dev/disk/by-partuuid ] ||
        fatal 'ZRAM cannot inspect installer block devices, swaps, mounts or PARTUUID links'
}

zram_probe_value() {
    printf '%s\n' "$zi_output" | sed -n "s/^$1=//p" | head -n 1
}

# The native blkid low-level probe supplies GPT PART_ENTRY_* fields even on
# raw partitions. sysfs exposes partition topology and size in 512B sectors.
zram_partition_info() {
    zi_device=$1
    [ -b "$zi_device" ] || return 1
    zi_name=$(basename "$zi_device")
    case "$zi_name" in ''|*[!a-zA-Z0-9_.-]*) return 1 ;; esac
    zi_sys="/sys/class/block/$zi_name"
    [ -r "$zi_sys/partition" ] && [ -r "$zi_sys/size" ] || return 1
    zi_partn=$(cat "$zi_sys/partition") || return 1
    zi_sectors=$(cat "$zi_sys/size") || return 1
    case "$zi_partn:$zi_sectors" in ''|*[!0-9:]*|:*|*:) return 1 ;; esac
    zi_parent=$(basename "$(dirname "$(readlink -f "$zi_sys")")") || return 1
    case "$zi_parent" in ''|*[!a-zA-Z0-9_.-]*) return 1 ;; esac
    zi_disk="/dev/$zi_parent"
    [ -b "$zi_disk" ] || return 1
    [ "$(blkid -p -s PTTYPE -o value "$zi_disk" 2>/dev/null)" = gpt ] || return 1
    zi_output=$(blkid -p -o export "$zi_device" 2>/dev/null || true)
    [ "$(zram_probe_value PART_ENTRY_SCHEME)" = gpt ] || return 1
    zi_partuuid=$(zram_probe_value PART_ENTRY_UUID | tr '[:upper:]' '[:lower:]')
    printf '%s\n' "$zi_partuuid" |
        grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' ||
        return 1
    zi_type=$(zram_probe_value PART_ENTRY_TYPE | tr '[:upper:]' '[:lower:]')
    [ "$(zram_probe_value PART_ENTRY_NUMBER)" = "$zi_partn" ] || return 1
    zi_entry_disk=$(zram_probe_value PART_ENTRY_DISK)
    if [ -n "$zi_entry_disk" ]; then
        [ "$zi_entry_disk" = "$(cat "/sys/class/block/$zi_parent/dev")" ] || return 1
    fi
    zi_label=$(zram_probe_value PART_ENTRY_NAME)
    zi_signature=$(zram_probe_value TYPE)
    zi_size_kib=$((zi_sectors / 2))
}

zram_is_mounted() {
    zm_name=$(basename "$zram_device")
    zm_id=$(cat "/sys/class/block/$zm_name/dev") ||
        fatal 'Cannot inspect selected partition mount identity'
    awk -v id="$zm_id" '$3 == id { found=1 } END { exit !found }' /proc/self/mountinfo
}

zram_ref_matches() (
    # Return success only when a target fstab source resolves to the exact
    # selected GPT partition. An arbitrary same-disk swap is NOT a match.
    zr_ref=$1
    zr_part=$2
    zr_dev=$3
    zr_swap_uuid=$4
    zr_swap_label=$5
    case "$zr_ref" in
        PARTUUID=*) [ "$(printf '%s' "${zr_ref#PARTUUID=}" | tr '[:upper:]' '[:lower:]')" = "$zr_part" ] ;;
        UUID=*) [ -n "$zr_swap_uuid" ] &&
            [ "$(printf '%s' "${zr_ref#UUID=}" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$zr_swap_uuid" | tr '[:upper:]' '[:lower:]')" ] &&
            [ "$(readlink -f -- "$(zram_blkid -t "UUID=$zr_swap_uuid" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        LABEL=*) [ -n "$zr_swap_label" ] && [ "${zr_ref#LABEL=}" = "$zr_swap_label" ] &&
            [ "$(readlink -f -- "$(zram_blkid -t "LABEL=$zr_swap_label" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        # PARTLABEL is not unique and cannot prove which raw partition
        # belongs to the target. Do not resolve it automatically.
        PARTLABEL=*) return 1 ;;
        /dev/*) [ "$(readlink -f -- "$zr_ref" 2>/dev/null || true)" = "$zr_dev" ] ;;
        *) return 1 ;;
    esac
)

zram_collect_candidates() {
    # Prefer swap in this target's fstab; allow manually selected existing raw backing.
    [ -f /target/etc/fstab ] || fatal 'No installed-target fstab: cannot identify assigned swap'
    [ -r /proc/self/mountinfo ] &&
        awk '$5 == "/target" { found=1 } END { exit !found }' /proc/self/mountinfo ||
        fatal 'Installed target root is not a separately mounted filesystem'
    : > "$WORK/zram-candidate-map"
    for zc_entry in /sys/class/block/*/partition; do
        [ -r "$zc_entry" ] || continue
        zc_device="/dev/$(basename "$(dirname "$zc_entry")")"
        zram_partition_info "$zc_device" || continue
        zc_kind=''
        if [ "$zi_type" = "$ZRAM_SWAP_GUID" ] && [ "$zi_signature" = swap ]; then
            zc_kind=swap
        elif [ "$zi_type" = "$ZRAM_DATA_GUID" ] &&
            [ "$zi_label" = zram-writeback ] &&
            { [ -z "$zi_signature" ] || [ "$zi_signature" = swap ]; }; then
            zc_kind=existing-raw
        fi
        [ -n "$zc_kind" ] || continue
        ! grep -q "^$zi_partuuid|" "$WORK/zram-candidate-map" ||
            fatal 'Duplicate GPT partition identity; refusing ZRAM selection'
        zc_size="$zi_size_kib KiB"
        printf '%s|%s|%s|%s\n' "$zi_partuuid" "$zc_device" "$zc_kind" "$zc_size" >> "$WORK/zram-candidate-map"
    done
    [ -s "$WORK/zram-candidate-map" ] ||
        fatal 'No eligible GPT swap or existing raw zram-writeback partition. Return to partitioning or deselect ZRAM.'
}

zram_choose_candidate() {
    # Automatic selection is authorized ONLY by one exact swap reference in
    # this newly installed target, never by partition age or disk proximity.
    awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}' \
        /target/etc/fstab > "$WORK/zram-target-swap-refs"
    za_count=0
    za_uuid=''
    if [ "$(wc -l < "$WORK/zram-target-swap-refs")" -eq 1 ]; then
        za_ref="$(cat "$WORK/zram-target-swap-refs")"
        while IFS='|' read -r za_id za_dev za_kind za_size; do
            za_swap_uuid="$(zram_blkid -s UUID -o value "$za_dev" 2>/dev/null || true)"
            za_swap_label="$(zram_blkid -s LABEL -o value "$za_dev" 2>/dev/null || true)"
            if [ "$za_kind" = swap ] &&
                zram_ref_matches "$za_ref" "$za_id" "$za_dev" "$za_swap_uuid" "$za_swap_label"; then
                za_count=$((za_count + 1))
                za_uuid=$za_id
            fi
        done < "$WORK/zram-candidate-map"
    fi
    if [ "$za_count" -eq 1 ]; then
        zram_uuid=$za_uuid
        zram_selection=automatic
        log "ZRAM assigned backing verified from target fstab: PARTUUID=$zram_uuid"
    else
        # Choices-C holds canonical PARTUUIDs; Choices holds display-only
        # device/size/type labels. The first choice is deliberately safe.
        za_ids=none
        za_labels='Stop without changing a partition'
        while IFS='|' read -r za_id za_dev za_kind za_size; do
            za_ids="$za_ids, $za_id"
            za_labels="$za_labels, $za_dev ($za_size; $za_kind; PARTUUID $za_id)"
        done < "$WORK/zram-candidate-map"
        db_subst my-cdd/zram-backing-select MYCDD_BACKING_IDS "$za_ids" ||
            fatal 'Cannot construct canonical ZRAM partition choices'
        db_subst my-cdd/zram-backing-select MYCDD_BACKING_LABELS "$za_labels" ||
            fatal 'Cannot display ZRAM partition choices'
        db_set my-cdd/zram-backing-select none || fatal 'Cannot reset ZRAM selection to safe default'
        db_fset my-cdd/zram-backing-select seen false || fatal 'Cannot present ZRAM selection'
        db_input critical my-cdd/zram-backing-select || fatal 'ZRAM partition chooser unavailable'
        db_go || fatal 'ZRAM partition chooser cancelled; no backing changed'
        db_get my-cdd/zram-backing-select || fatal 'Cannot read ZRAM partition choice'
        zram_uuid=$RET
        [ "$zram_uuid" != none ] && [ -n "$zram_uuid" ] ||
            fatal 'No backing partition was selected; nothing modified'
        zram_selection=manual
        log "USER SELECTED ZRAM backing in native partition list: PARTUUID=$zram_uuid"
    fi
    zram_device=''
    zram_kind=''
    zram_size=''
    zram_hits=0
    while IFS='|' read -r za_id za_dev za_kind za_size; do
        if [ "$za_id" = "$zram_uuid" ]; then
            zram_hits=$((zram_hits + 1))
            zram_device=$za_dev
            zram_kind=$za_kind
            zram_size=$za_size
        fi
    done < "$WORK/zram-candidate-map"
    [ "$zram_hits" -eq 1 ] || fatal 'Chosen partition is not a unique verified candidate'
    zram_validate_candidate
}

zram_validate_candidate() {
    # Re-check live identity, active use and mounts before destructive changes.
    zc_link="/dev/disk/by-partuuid/$zram_uuid"
    [ -b "$zc_link" ] || fatal 'Selected PARTUUID block device is missing'
    [ "$(readlink -f "$zc_link")" = "$zram_device" ] ||
        fatal 'Backing device has changed since selection'
    zram_partition_info "$zram_device" ||
        fatal 'Selected backing is not a readable GPT partition'
    [ "$zi_partuuid" = "$zram_uuid" ] ||
        fatal 'Backing PARTUUID changed before conversion'
    parent=$zi_parent
    partn=$zi_partn
    disk=$zi_disk
    [ "$zi_sectors" -ge 2048 ] ||
        fatal 'Selected backing is smaller than the required 1 MiB signature erase'
    # Cloned disks can duplicate a PARTUUID even on ineligible partitions.
    zc_hits=0
    for zc_entry in /sys/class/block/*/partition; do
        [ -r "$zc_entry" ] || continue
        zc_other="/dev/$(basename "$(dirname "$zc_entry")")"
        zram_partition_info "$zc_other" || continue
        if [ "$zi_partuuid" = "$zram_uuid" ]; then
            zc_hits=$((zc_hits + 1))
        fi
    done
    [ "$zc_hits" -eq 1 ] ||
        fatal 'Selected PARTUUID occurs on multiple block partitions; refusing ambiguous backing'
    zram_partition_info "$zram_device" ||
        fatal 'Selected backing vanished during validation'
    case "$zram_kind" in
        swap)
            [ "$zi_type" = "$ZRAM_SWAP_GUID" ] && [ "$zi_signature" = swap ] ||
                fatal 'Backing is no longer a conventional GPT swap partition' ;;
        existing-raw)
            [ "$zi_type" = "$ZRAM_DATA_GUID" ] &&
                [ "$zi_label" = zram-writeback ] &&
                { [ -z "$zi_signature" ] || [ "$zi_signature" = swap ]; } ||
                fatal 'Previously converted backing no longer matches raw GPT identity' ;;
        *) fatal 'Unknown ZRAM backing class' ;;
    esac
    for zc_holder in "/sys/class/block/$(basename "$zram_device")/holders/"*; do
        [ ! -e "$zc_holder" ] || fatal 'Selected ZRAM backing is held by another block device'
    done
    ! zram_is_mounted ||
        fatal 'Selected backing has filesystem mounts; refusing conversion'
}

zram_read_active_swap() {
    # /proc/swaps reports KiB used; preserve byte units for RAM checks/prompts.
    active_used=''
    [ -r /proc/swaps ] || fatal 'Cannot enumerate installer-active swap'
    while read -r zs_path zs_type zs_size zs_used zs_priority; do
        [ "$zs_path" != Filename ] || continue
        [ -n "$zs_path" ] || continue
        if [ "$(readlink -f "$zs_path" 2>/dev/null || true)" = "$zram_device" ]; then
            [ -z "$active_used" ] || fatal 'Duplicate active-swap mapping for the chosen partition'
            case "$zs_used" in ''|*[!0-9]*) fatal 'Invalid used-swap KiB count' ;; esac
            active_used=$((zs_used * 1024))
        fi
    done < /proc/swaps
}

zram_prepare_fstab() {
    # Build the edited target fstab BEFORE modifying any partition. Preserve
    # every unrelated line byte-for-byte and remove only matching swap lines.
    cp /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Cannot snapshot installed fstab before ZRAM conversion'
    : > "$WORK/zram-safe-fstab"
    while IFS= read -r zf_line || [ -n "$zf_line" ]; do
        zf_ref="$(printf '%s\n' "$zf_line" |
            awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}')"
        case "$zf_ref" in
            PARTLABEL=*) fatal 'Ambiguous PARTLABEL swap reference in target fstab; resolve it before ZRAM conversion' ;;
            UUID=*)
                case "$former_uuid" in
                    '') ;;
                    *) if [ "${zf_ref#UUID=}" = "$former_uuid" ] &&
                        ! zram_ref_matches "$zf_ref" "$zram_uuid" "$zram_device" "$former_uuid" "$former_label"; then
                        fatal 'Target fstab swap UUID is duplicated or cannot be resolved uniquely'
                    fi ;;
                esac ;;
            LABEL=*)
                case "$former_label" in
                    '') ;;
                    *) if [ "${zf_ref#LABEL=}" = "$former_label" ] &&
                        ! zram_ref_matches "$zf_ref" "$zram_uuid" "$zram_device" "$former_uuid" "$former_label"; then
                        fatal 'Target fstab swap LABEL is duplicated or cannot be resolved uniquely'
                    fi ;;
                esac ;;
        esac
        if [ -n "$zf_ref" ] &&
            zram_ref_matches "$zf_ref" "$zram_uuid" "$zram_device" "$former_uuid" "$former_label"; then
            log "Removing confirmed backing conventional-swap fstab reference: $zf_ref"
            continue
        fi
        printf '%s\n' "$zf_line" >> "$WORK/zram-safe-fstab"
    done < "$WORK/zram-original-fstab"
    # Never leave a second conventionally activated swap configured in the
    # new target; modifying or deactivating that other device is NOT approved.
    if awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}' \
        "$WORK/zram-safe-fstab" | grep -q .; then
        fatal 'Another target swap entry would remain; do not enable independent swap alongside required ZRAM'
    fi
}
````

</details>

<details>
<summary><strong>scripts/zram-generator.conf.template</strong> — complete file; 10 lines; original blob <code>bd95dec18d1a82a7d8723d0984f0cb11730c15b3</code></summary>

````text
# Early unit generation may precede creation of the PARTUUID symlink.
# The generator re-reads the configuration during device setup.
set!backingBytes = /usr/sbin/blockdev --getsize64 /dev/disk/by-partuuid/YOUR_PARTUUID 2>/dev/null || echo 0

[zram0]
zram-size = ram + backingBytes / 1048576
zram-resident-limit = ram / 2
compression-algorithm = zstd
writeback-device = /dev/disk/by-partuuid/YOUR_PARTUUID
swap-priority = 100
````

</details>

<details>
<summary><strong>scripts/10-compressed-writeback.conf</strong> — complete file; 2 lines; original blob <code>901ebe1d7c228bb4053cc56ea766854048ba5f0f</code></summary>

````ini
[Service]
ExecStartPre=/bin/sh -c 'echo yes > /sys/block/zram0/compressed_writeback'
````

</details>

<details>
<summary><strong>scripts/zram-pressure.sh</strong> — complete file; 76 lines; original blob <code>9a40b02f7bb80504c1f4a6d831d2ca4ac08cbf3d</code></summary>

````sh
#!/usr/bin/env bash
set -Eeuo pipefail

Z=/sys/block/zram0
POLL=1
START=80
TARGET=70
EMERGENCY=95
PSI_MIN=500                  # 5.00% as hundredths of a percent
AGES=(86400 21600 3600 300 60)

state() {
    local kind avg whole fraction
    read -r _ _ used limit _ < "$Z/mm_stat" || return 1
    (( limit > 0 )) || return 1
    read -r kind avg _ < /proc/pressure/memory || return 1
    [[ $kind == some && $avg =~ ^avg10=([0-9]+)\.([0-9]{2})$ ]] || return 1
    whole=${BASH_REMATCH[1]}
    fraction=${BASH_REMATCH[2]}
    psi=$(( 10#$whole * 100 + 10#$fraction ))
    occupancy=$(( used * 100 / limit ))
}

for name in mm_stat idle writeback bd_stat compressed_writeback writeback_limit_enable; do
    [[ -e $Z/$name ]] || { echo "Missing $Z/$name" >&2; exit 1; }
done
read -r value < "$Z/compressed_writeback"
[[ $value == 1 ]] || { echo 'Compressed writeback is not enabled' >&2; exit 1; }
read -r value < "$Z/writeback_limit_enable"
[[ $value == 0 ]] || { echo 'Disable writeback_limit before starting' >&2; exit 1; }

while :; do
    state || { echo 'Cannot read PSI/zram state' >&2; exit 1; }
    if (( occupancy < EMERGENCY && (occupancy < START || psi < PSI_MIN) )); then
        sleep "$POLL"
        continue
    fi

    echo "Writeback triggered: zram=${occupancy}% PSI=${psi}bp"
    read -r _ _ before < "$Z/bd_stat"
    failed=0

    for age in "${AGES[@]}"; do
        state || exit 1
        # Once started, continue only while pressure + insufficient
        # headroom persist, or the emergency threshold is reached.
        if (( occupancy < EMERGENCY && (occupancy < TARGET || psi < PSI_MIN) )); then
            break
        fi
        if ! printf '%s\n' "$age" > "$Z/idle" ||
           ! printf '%s\n' 'type=idle' > "$Z/writeback"; then
            echo "Writeback failed for age=${age}s" >&2
            failed=1
            break
        fi
        echo "Writeback completed: age=${age}s"
    done

    state || exit 1
    if (( failed == 0 && occupancy >= EMERGENCY )); then
        echo 'Emergency writeback: all remaining eligible entries'
        if ! printf '%s\n' all > "$Z/idle" ||
           ! printf '%s\n' 'type=idle' > "$Z/writeback"; then
            echo 'Emergency writeback failed' >&2
            failed=1
        fi
    fi

    read -r _ _ after < "$Z/bd_stat"
    echo "Cycle complete; backing writes delta=$((after - before))"
    if (( failed || after == before )); then
        sleep 30                 # Avoid rapid retries on full/ineffective backing
    else
        sleep "$POLL"
    fi
done
````

</details>

<details>
<summary><strong>scripts/zram-pressure.service</strong> — complete file; 13 lines; original blob <code>14c1716d05700ab187a64d8bf4474f41dcd1bced</code></summary>

````ini
[Unit]
Description=Pressure-triggered zram writeback
BindsTo=dev-zram0.swap
After=dev-zram0.swap

[Service]
Type=exec
ExecStart=/usr/local/sbin/zram-pressure.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
````

</details>

<details>
<summary><strong>scripts/90-zram-swappiness.conf</strong> — complete file; 3 lines; original blob <code>290648ab923c198a74a4c11774df270e01b679ab</code></summary>

````ini
# Deploy ONLY when the ZRAM profile was explicitly selected.
# Not a Debian tweaks default and never deployed for unselected ZRAM.
vm.swappiness = 100
````

</details>
