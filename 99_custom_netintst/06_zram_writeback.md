# 06 — Recreate the ZRAM writeback installer profile

**Goal:** reconstruct the exact source of this **destructive, optional Debian Installer feature**, including selection, confirmation, native GPT conversion and ZSTD ZRAM writeback configuration. Do not copy the following installer commands into a normal Debian terminal. For that use [06 — Standalone ZRAM](../06_zram_writeback/README.md) with ordinary full-system tools.

**Safety:** this handler can zero the first **1 MiB of a GPT partition**. Only test on a disposable virtual disk. The earlier VM confirmed a partition conversion, but the revised installation order and first-boot compressed writeback remain unverified.

## Step 1 — Complete the prerequisites

1. Build the Simple-CDD project in [Build project](build_project.md).
2. Create the shared code and profile rules in [Shared profile helpers](profile_construction.md).
3. Create the native early/late selection UI and dispatcher in [Installer framework](installer_framework.md).
4. Also create the **independently selectable Linux 7.x profile** from [04 — Linux 7.x](04_ensure_7x_kernel.md). ZRAM may not run unless that profile was separately selected and successfully completed.

The build-only `profiles/installer-media.udebs` already includes `parted-udeb` and `util-linux-udeb` from [Build project](build_project.md); they provide native commands in the installer, not the installed target. The default Debconf template in [Installer framework](installer_framework.md) supplies the separate default-No ZRAM destructive and swapoff questions.

Work inside `99_custom_netintst/my-cdd/`, on a test branch or scratch copy.

## Step 2 — Know exactly which files make up the feature

Ten source/configuration files make up the profile, including a native Simple-CDD completion verifier.

| File to create | Reason |
| --- | --- |
| `profiles/zram-writeback.description` | Text of the opt-in ZRAM checkbox. |
| `profiles/zram-writeback.extra` | All required sources and generator/monitor assets to stage on the installer ISO. |
| `profiles/zram-writeback.postinst` | Native Simple-CDD completion verifier; checks a marker without rerunning feature installation. |
| `installer/zram-writeback.sh` | The complete selected-only handler: inline utility preflight, confirmation, targeted swapoff, bounded erase, native Parted, fstab, hibernation resume and target provisioning. |
| `installer/zram-writeback-selection.sh` | The complete native GPT/sysfs/blkid candidate discovery, identity validation, mount/holder checks and fstab preparation; `blkid` is called directly. |
| `scripts/zram-generator.conf.template` | ZSTD/ZRAM sizing and writeback config; dynamically replaced PARTUUID placeholders. |
| `scripts/override.conf` | Single systemd drop-in for pre-init compressed writeback and setup-failure emergency policy. |
| `scripts/zram-pressure.sh` | Complete script monitoring memory pressure and issuing writeback operations. |
| `scripts/zram-pressure.service` | Systemd service to supervise and restart the pressure monitor. |
| `scripts/90-zram.conf` | Swappiness setting applicable only to the explicitly selected ZRAM feature. |


Native Debian Installer stage `61my-cdd` runs each approved selected handler **once**, then writes that profile's success marker. Unmodified Simple-CDD stage `62simple-cdd` executes the selected profile's verification-only `.postinst` **in-target**. Stage `63my-cdd-status` independently checks all approved markers and overall `COMPLETE`, returning native exit 10 rather than falsely reporting success.

## Step 3 — Create each file

Prepare the source folders:

~~~sh
mkdir -p profiles installer scripts
~~~

This creates project directories only, not partitions.

**1. Create `profiles/zram-writeback.description`.** Text of the opt-in ZRAM checkbox.

Open `profiles/zram-writeback.description` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**2. Create `profiles/zram-writeback.extra`.** All required sources and generator/monitor assets to stage on the installer ISO.

Open `profiles/zram-writeback.extra` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**3. Create `installer/zram-writeback.sh`.** The complete selected-only handler: confirmation, targeted swapoff, bounded erase, native Parted, fstab, hibernation resume and target provisioning.

Open `installer/zram-writeback.sh` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**4. Create `installer/zram-writeback-selection.sh`.** The complete installer-native GPT/sysfs/blkid candidate discovery, identity validation, mount/holder checks and fstab preparation.

Open `installer/zram-writeback-selection.sh` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**5. Create `scripts/zram-generator.conf.template`.** ZSTD/ZRAM sizing and writeback config; dynamically replaced PARTUUID placeholders.

Open `scripts/zram-generator.conf.template` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**6. Create `scripts/override.conf`.** Single systemd drop-in for compressed writeback before initialization and emergency mode on setup failure.

Open `scripts/override.conf` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**7. Create `scripts/zram-pressure.sh`.** Complete script monitoring memory pressure and issuing writeback operations.

Open `scripts/zram-pressure.sh` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**8. Create `scripts/zram-pressure.service`.** Systemd service to supervise and restart the pressure monitor.

Open `scripts/zram-pressure.service` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.

**9. Create `scripts/90-zram.conf`.** Swappiness setting applicable only to the explicitly selected ZRAM feature.

Open `scripts/90-zram.conf` in a text editor, paste the indicated contents and save it at that path.

This opens a source file without executing it. Expand the **complete listing for that same path below**, Save the document after reviewing the pasted contents. Do **not** run the installer-side commands outside the installer; in particular `dd`, `swapoff` and `parted` lines belong in the module only.




The main `installer/zram-writeback.sh` handler is **sourced**; it is never invoked as a standalone host program.

## Step 4 — Understand how the complete code fits together

1. **Profile consent is not disk consent.** `simple-cdd.conf` offers the optional `zram-writeback` checkbox, but the shared selector rejects it without independently selected `ensure-7x-kernel`. The dispatcher maps the ZRAM name to `profile_zram()`.
2. **Installer-native tools:** the handler loads `parted-udeb` / `util-linux-udeb` when absent, checks native BusyBox `dd` and `swapoff` applets, and sources `zram-writeback-selection.sh`.
3. **Candidate discovery:** the selection helper uses `/sys/class/block` and native `blkid -p -o export` to inspect GPT partition number, parent disk, GUID type and **actual PARTUUID**. It accepts GPT swap-type partitions, plus already prepared raw partitions named `zram-writeback`. It rejects duplicate identities, mounts and block-device holders.
4. **Automatic choice is narrowly limited:** exactly one suitable conventional swap reference in the new target's `/target/etc/fstab` may be selected automatically. Otherwise the native Debconf chooser presents the exact candidates and initially offers **Stop**.
5. **Independent destructive approval:** after selecting a candidate, the handler shows the exact partition device, parent disk, size, PARTUUID and planned **first-1-MiB erase**. The default is **No**.
6. **Active swap:** the installer reads `/proc/swaps` and asks a separate default-No confirmation for targeted `swapoff` only if the chosen partition is active. It does not impose a RAM-reserve or memory-pressure threshold. An actual failed `swapoff` or still-active backing stops the destructive conversion.
7. **fstab preparation:** before writes, the helper prepares removal of only the confirmed partition's conventional swap entry. Unrelated root, EFI, NAS, **other swap references and partitions** remain untouched. There is no separate whole-system swap policy.
8. **Resume identification and bounded signature erase:** Read the target's native resume configuration and match the selected partition before its swap UUID/label is erased. once all checks pass, the handler runs BusyBox `dd` with `bs=4096 count=256` against the **verified partition**, not its parent disk. That writes exactly **1 MiB**.
9. **GPT conversion without recreation:** native Parted changes that partition's **type** to standard Linux data (gdisk 8300, GUID `0FC63DAF-8483-4772-8E79-3D69D8477DE4`) and its **name** to `zram-writeback`. It does **not** format a filesystem, delete the partition or hardcode the machine's PARTUUID. Post-write checks must confirm correct identity and no residual swap signature.
10. **Target provisioning:** an atomically staged `fstab` is installed. If the original resume device matched the backing or no conventional fstab swap remains, write `RESUME=none` to the target's standard initramfs resume file; otherwise preserve the existing configuration. Rebuild all installed initramfs images with `update-initramfs -u -k all` before continuing. Custom resume overrides and kernel command-line parameters are outside this correction. The user approves installing `systemd-zram-generator`; both template `YOUR_PARTUUID` placeholders are replaced with the **actual detected PARTUUID**. The generator, single setup override, pressure monitor and swappiness file are installed under `/target`; GRUB is updated for `zswap.enabled=0`.

## Step 5 — Check copied source before any disk operation

~~~sh
sh -n installer/zram-writeback.sh
~~~

This syntax-checks the main handler without running it.

~~~sh
sh -n installer/zram-writeback-selection.sh
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
<summary><strong>profiles/zram-writeback.extra</strong> — complete file; 8 lines; original blob <code>5c40044f3a181a1dd46b7e6b65a6004f79d77b19</code></summary>

````text
# zram-writeback: source assets copied by Simple-CDD (not automatically installed).
installer/zram-writeback.sh
installer/zram-writeback-selection.sh
scripts/zram-generator.conf.template
scripts/override.conf
scripts/zram-pressure.sh
scripts/zram-pressure.service
scripts/90-zram.conf
````

</details>



<details>
<summary><strong>installer/zram-writeback.sh</strong> — complete file; 202 lines; current Git blob <code>8dbb1e7128c2b26ae7360ca8d442f705539ca865</code></summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_zram() {
    # ordered-selection requires the separately selected kernel profile,
    # and the native stage-61 runner executes it before ZRAM. Any failure
    # prevents reaching this handler; no duplicate completion marker needed.
    [ -r "$MEDIA/zram-generator.conf.template" ] ||
        fatal 'Original ZRAM generator source missing'
    [ -r "$MEDIA/zram-writeback-selection.sh" ] ||
        fatal 'Installer ZRAM selection helper missing'
    . "$MEDIA/zram-writeback-selection.sh"
    # The installer is a minimal udeb environment. The official parted-udeb
    # supplies the installer-native GPT editing CLI and matching udeb libraries.
    # Simple-CDD stages it via the build-only installer-media.udebs profile;
    # anna-install loads it only for an explicitly chosen ZRAM profile.
    # Do not copy normal target binaries or libraries into Debian Installer.
    if ! command -v parted >/dev/null 2>&1; then
        command -v anna-install >/dev/null 2>&1 ||
            fatal 'Native Debian Installer anna-install is unavailable for parted-udeb'
        progress_status 'Loading installer partition tools'
        progress_handoff
        capture anna-install parted-udeb ||
            fatal 'Could not load official parted-udeb into Debian Installer'
    fi
    command -v parted >/dev/null 2>&1 ||
        fatal 'Official parted-udeb did not provide a usable parted command'
    # Load installer-native blkid from util-linux-udeb when absent.
    if ! command -v blkid >/dev/null 2>&1; then
        progress_status 'Loading installer block-device tools'
        progress_handoff
        capture anna-install util-linux-udeb ||
            fatal 'Could not load official util-linux-udeb into Debian Installer'
    fi
    # Check all remaining installer utilities before a destructive conversion.
    # Prerequisites belong to this one-time ZRAM profile operation.
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
    progress_status 'Inspecting writeback partition candidates'
    zram_collect_candidates
    zram_choose_candidate
    uuid=$zram_uuid
    device=$zram_device
    size=$zram_size
    former_uuid="$(blkid -s UUID -o value "$device" 2>/dev/null || true)"
    former_label="$(blkid -s LABEL -o value "$device" 2>/dev/null || true)"
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

    # Debian Installer may activate the selected swap partition temporarily.
    # Deactivate ONLY this confirmed partition, with the separately approved
    # targeted swapoff. Do not veto an empty installer swap on RAM estimates.
    zram_read_active_swap
    if [ -n "$active_used" ]; then
        db_subst my-cdd/zram-swapoff MYCDD_PARTITION "$device" ||
            fatal 'Cannot show exact swapoff target'
        db_subst my-cdd/zram-swapoff MYCDD_USED "$active_used" ||
            fatal 'Cannot show selected swap usage'
        yes_no my-cdd/zram-swapoff ||
            fatal 'Targeted swapoff was not separately approved'
        zram_validate_candidate
        zram_read_active_swap
        if [ -n "$active_used" ]; then
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
        fatal 'Selected backing is active swap; cannot overwrite its signature'

    # Identify the configured resume device while its old swap signature
    # and UUID/label aliases still exist. Read the native Debian resume file
    # in the target, not the installer's own initramfs configuration.
    resume_ref="$(chroot /target /bin/sh -c '
        unset RESUME
        if [ -f /etc/initramfs-tools/conf.d/resume ]; then
            . /etc/initramfs-tools/conf.d/resume || exit 1
        fi
        printf "%s" "${RESUME-}"
    ')" || fatal 'Cannot read target hibernation resume configuration'
    resume_on_backing=false
    if zram_ref_matches "$resume_ref" "$uuid" "$device" "$former_uuid" "$former_label"; then
        resume_on_backing=true
    fi

    # Write only the approved partition's first 1 MiB, never its parent disk.
    # The GPT layout and PARTUUID are preserved; no filesystem is created.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after verification; conversion stopped'
    log "USER APPROVED CONVERSION: $device, PARTUUID=$uuid, size=$size"
    progress_status 'Preparing the explicitly approved writeback partition'
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
    # The converted raw backing cannot serve as a hibernation resume device.
    # Disable resume if it pointed to this partition or no conventional
    # target fstab swap remains. Preserve other configured resume devices.
    if [ "$resume_on_backing" = true ] || [ ! -s "$WORK/zram-residual-swaps" ]; then
        progress_status 'Updating hibernation resume configuration'
        mkdir -p /target/etc/initramfs-tools/conf.d ||
            fatal 'Cannot locate target initramfs configuration directory'
        printf 'RESUME=none\n' > /target/etc/initramfs-tools/conf.d/resume ||
            fatal 'Cannot disable obsolete hibernation resume configuration'
        log 'ZRAM conversion: RESUME=none (converted resume device or no remaining fstab swap)'
    fi
    # Rebuild every installed initramfs after removing the old swap signature
    # and fstab entry, including when resume configuration is preserved.
    run_target update-initramfs -u -k all
    # No other ZRAM provisioning occurs until the partition conversion
    # (type, name, PARTUUID, signatures, swap and resume state) has passed.

    review_install 'ZRAM generator package and all dependencies' systemd-zram-generator
    mkdir -p /target/etc/systemd/system/systemd-zram-setup@zram0.service.d \
        /target/etc/systemd/system /target/etc/sysctl.d /target/usr/local/sbin
    sed "s/YOUR_PARTUUID/$uuid/g" "$MEDIA/zram-generator.conf.template" > \
        /target/etc/systemd/zram-generator.conf
    [ "$(grep -o "$uuid" /target/etc/systemd/zram-generator.conf | wc -l)" -eq 2 ] &&
        ! grep -q YOUR_PARTUUID /target/etc/systemd/zram-generator.conf ||
        fatal 'ZRAM generator configuration contains unresolved or mismatched backing identity'
    # One drop-in covers pre-initialization compressed writeback and setup failure.
    cp "$MEDIA/override.conf" \
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/override.conf
    cp "$MEDIA/zram-pressure.sh" /target/usr/local/sbin/zram-pressure.sh
    chmod 755 /target/usr/local/sbin/zram-pressure.sh
    cp "$MEDIA/zram-pressure.service" /target/etc/systemd/system/zram-pressure.service
    cp "$MEDIA/90-zram.conf" /target/etc/sysctl.d/90-zram.conf
    # zswap must not intercept memory intended for zram.
    if ! grep -q 'zswap.enabled=0' /target/etc/default/grub; then
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ zswap.enabled=0"/' /target/etc/default/grub
    fi
    run_target update-grub
    run_target systemctl enable zram-pressure.service
    log "ZRAM raw backing: $device PARTUUID=$uuid size=$size; boot kernel/sysfs and generator require first-boot validation"
}

````

</details>

<details>
<summary><strong>installer/zram-writeback-selection.sh</strong> — complete file; 267 lines; current Git blob <code>e600dff3e04641bc4e7cb51d4eb08d31b0e093c3</code></summary>

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
            [ "$(readlink -f -- "$(blkid -t "UUID=$zr_swap_uuid" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        LABEL=*) [ -n "$zr_swap_label" ] && [ "${zr_ref#LABEL=}" = "$zr_swap_label" ] &&
            [ "$(readlink -f -- "$(blkid -t "LABEL=$zr_swap_label" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
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
            za_swap_uuid="$(blkid -s UUID -o value "$za_dev" 2>/dev/null || true)"
            za_swap_label="$(blkid -s LABEL -o value "$za_dev" 2>/dev/null || true)"
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
<summary><strong>scripts/override.conf</strong> — complete file; 6 lines; original blob <code>aa3b1e83a4ab4f0857287890483715a4e3ffd16b</code></summary>

````ini
[Unit]
OnFailure=emergency.target
OnFailureJobMode=replace-irreversibly

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
<summary><strong>scripts/90-zram.conf</strong> — complete file; 3 lines; original blob <code>290648ab923c198a74a4c11774df270e01b679ab</code></summary>

````ini
# Deploy ONLY when the ZRAM profile was explicitly selected.
# Not a Debian tweaks default and never deployed for unselected ZRAM.
vm.swappiness = 100
````

</details>
 ||
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
            [ "$(readlink -f -- "$(blkid -t "UUID=$zr_swap_uuid" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        LABEL=*) [ -n "$zr_swap_label" ] && [ "${zr_ref#LABEL=}" = "$zr_swap_label" ] &&
            [ "$(readlink -f -- "$(blkid -t "LABEL=$zr_swap_label" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
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
            za_swap_uuid="$(blkid -s UUID -o value "$za_dev" 2>/dev/null || true)"
            za_swap_label="$(blkid -s LABEL -o value "$za_dev" 2>/dev/null || true)"
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
<summary><strong>scripts/override.conf</strong> — complete file; 6 lines; original blob <code>aa3b1e83a4ab4f0857287890483715a4e3ffd16b</code></summary>

````ini
[Unit]
OnFailure=emergency.target
OnFailureJobMode=replace-irreversibly

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
<summary><strong>scripts/90-zram.conf</strong> — complete file; 3 lines; original blob <code>290648ab923c198a74a4c11774df270e01b679ab</code></summary>

````ini
# Deploy ONLY when the ZRAM profile was explicitly selected.
# Not a Debian tweaks default and never deployed for unselected ZRAM.
vm.swappiness = 100
````

</details>

## Native Simple-CDD completion verifier

Create `profiles/zram-writeback.postinst` from the full source below, alongside its `.description` and `.extra` files. The stage-61 runner writes its record after successful handler execution; the original `62simple-cdd` hook runs this verifier in-target without installing the feature twice.

~~~sh
chmod +x profiles/zram-writeback.postinst
sh -n profiles/zram-writeback.postinst
~~~

The syntax check is read-only. The final `63my-cdd-status` guard also checks this selected profile's record, returning exit 10 if any required record is missing.

<details>
<summary><strong>profiles/zram-writeback.postinst</strong> — complete native verifier (11 lines; Git blob <code>9600b6690b1ea86d2e079fbd46ccad6434752137</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-61 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/zram-writeback"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'zram-writeback'
    exit 1
fi
````

</details>
