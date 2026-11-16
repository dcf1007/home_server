# Netinst — Prepare and build the custom Debian image

**Purpose:** build a Debian 13 amd64 netinst image containing the usual Debian Installer and seven **optional** Simple-CDD features. This is a build-host procedure, **not** something to run on the NAS after installing Debian.

## Step 1 — Use a suitable Debian build machine

Start from a normal Debian system with Internet access and enough free disk space for a Debian mirror cache and ISO. It can be a VM. Installing the build tools does **not** modify the target NAS.

Update the build machine's available APT package information:

~~~sh
sudo apt update
~~~

Install Git (repository checkout), Simple-CDD (custom ISO assembly), and reprepro (local package-index generation). Read APT's proposed changes before accepting:

~~~sh
sudo apt install git simple-cdd reprepro
~~~

## Step 2 — Obtain and inspect the source

Download the project, unless you already have it:

~~~sh
git clone https://github.com/dcf1007/home_server.git
~~~

This creates a local `home_server` directory; it does not install any server features. On an existing checkout, use `git pull --ff-only` after making sure local changes are saved.

Enter the actual ISO project's build directory:

~~~sh
cd home_server/99_custom_netintst/my-cdd
~~~

All following commands run **from this directory**. Review [`simple-cdd.conf`](my-cdd/simple-cdd.conf) for the fixed Debian version, architecture and profile list. Do not select all profiles merely by editing the build configuration.

## Step 3 — Review the installer defaults

Open [`profile_defaults.conf`](my-cdd/profile_defaults.conf) in an editor. It supplies **editable suggestions** to Debian Installer, such as English, Spain-style keyboard, Germany, Europe/Berlin, DHCP, headless tasks and example hostname/admin username.

This is **not** an installer preseed to copy to the NAS. `build.sh` renders the actual boot/preseed defaults from it. Change the suggestions only if you want different initial answers on the installer screens. Never add passwords, device paths or automatic profile selections.

Review [`simple-cdd.conf`](my-cdd/simple-cdd.conf) again:

- `profiles` lists the **seven selectable** features.
- `auto_profiles=""` and `default_profiles=""` keep all optional features unchecked.
- `build_profiles="installer-media"` is only an ISO dependency list, **not** an eighth checkbox.
- `INSTALLER_CD="2"` includes the base Debian system; additional packages are fetched over the network.
- `BOOT_TIMEOUT="0"` requests an indefinite boot-menu wait, which still needs testing.

## Step 4 — Understand the installer-only dependencies

The normal [ZRAM procedure](../05_zram_writeback/README.md) uses full Debian utilities. The minimal Debian Installer instead needs the following **on its media**:

| Package | Why the custom installer needs it |
| --- | --- |
| `parted-udeb` | Change the selected partition's GPT type and name |
| `util-linux-udeb` | Provide installer-native `blkid` partition probing |
| `busybox-udeb` | Supply small native commands including the approved targeted `swapoff` and 1 MiB `dd` |
| Regular `zstd` binary on the ISO | Historical media prerequisite; kernel ZSTD compression is separate |

The build-only [`installer-media.udebs`](my-cdd/profiles/installer-media.udebs) includes the required additional udebs. The build script checks their indexes and archives. This does **not yet prove** a running installer can load their dependency closure successfully.

## Step 5 — Build the image

Run the project-supplied build command:

~~~sh
./build.sh
~~~

**What it does:** validates shell syntax and essential project input, generates the defaults, prepares the local mirror using Simple-CDD, builds the ISO, then checks that required binaries and udebs are present. It uses Simple-CDD's **mirror-only** then **build-only** stages rather than replacing upstream `default.*` installer lists.

Read the terminal output. If it fails, stop and inspect the log files in this build directory (including `build-mirror-debug.log`, `build-debug.log` and `build-terminal.log`). Fix the reported problem before using the image.

When successful, look for:

`images/debian-13-amd64-CD-1.iso`

Check that the ISO actually exists in the `my-cdd/images/` directory. **Do not assume that a successful ISO build means the profiles work during installation.**

## Step 6 — Boot-test with a disposable disk

Create a VM with a temporary disk and boot the ISO. Follow [05 — Installer screens and base Debian](05_base_installation.md) and the per-profile walkthroughs. Exercise one profile at a time before the full set. See [08 — Validation](08_validation_and_pending.md) for the required checkpoints.

**Known limitation:** a ZRAM conversion and first-boot writeback have **not** passed a live installer test following the latest native-udeb refactor.
