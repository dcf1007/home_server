# 07 — Build the independently selectable Docker installer profile

**Build goal:** create a Simple-CDD profile that adds Docker's signed Debian 13 source **inside the target**, simulates installation of the five official packages, requests default-No approval, then installs them without changing vendor service defaults.

For ordinary Debian commands, use [08 — Docker](../08_docker/README.md). Do **not** execute these installer-specific snippets on a normal host.

## Step 1 — Stage the module and register the choice

Create `profiles/docker.description` with a human-facing explanation and `profiles/docker.extra`:

~~~text
installer/profile-docker.sh
~~~

Add `docker` to the offered Simple-CDD profile list **without** changing `auto_profiles=""`. The existing dispatch mapping is:

~~~sh
docker) module=docker; handler=profile_docker ;;
~~~

Write a sourced `profile_docker()` function in `installer/profile-docker.sh`. Its `profiles/docker.postinst` is only a completion-marker check.

## Step 2 — Install key-download prerequisites through reviewed APT

The first action in `profile_docker` is:

~~~sh
review_install 'Docker signing prerequisites' ca-certificates curl
~~~

**Purpose:** install HTTPS CA verification and a downloader in `/target`. The shared helper simulates APT, shows the complete plan, obtains default-No approval, installs and audits the result. Do not assume they exist in a minimal Debian target.

## Step 3 — Download Docker's signing key to the target

Create `/target/etc/apt/keyrings`, then download the official key into the **target's path**, not the installer's temporary root:

~~~sh
mkdir -p /target/etc/apt/keyrings
capture in-target curl -fsSL --proto '=https' \
    -o /etc/apt/keyrings/docker.asc https://download.docker.com/linux/debian/gpg ||
    fatal 'Official Docker signing key download failed'
chmod 644 /target/etc/apt/keyrings/docker.asc
~~~

This code belongs **inside the selected function**. `capture in-target` uses `--pass-stdout` and records failures. The key is downloaded from the official Docker URL; APT will restrict the source to this key with `Signed-By`.

Check that the installed Debian target reports **`VERSION_CODENAME=trixie`**. Fail rather than guessing a source suite.

## Step 4 — Construct the exact signed Deb822 source

Write `/target/etc/apt/sources.list.d/docker.sources` with these contents:

~~~text
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
~~~

The current profile writes the file with a shell here-document. This is an **installed-target APT source**, not an ISO repository profile or an OMV plugin. It must not be added unconditionally when Docker was not selected.

Refresh target APT with `update_signed_apt`. For **each** package below, inspect `apt-cache policy` and confirm the official `download.docker.com/linux/debian` origin appears in the output.

## Step 5 — Build and review the exact Docker package transaction

The requested package set is:

- `docker-ce` (Engine daemon);
- `docker-ce-cli` (CLI);
- `containerd.io` (runtime);
- `docker-buildx-plugin` (Buildx);
- `docker-compose-plugin` (`docker compose`).

The real source uses this simulation:

~~~sh
simulate_target install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
check_critical_removals
review_plan 'Docker: official packages and normal service defaults' "$WORK/plan"
~~~

**Purpose:** show the complete dependencies, installations and removals. Reject plans that remove kernel, GRUB, SSH, sudo, systemd, APT or dpkg components. The native Debconf approval defaults to **No**.

## Step 6 — Install the approved packages without changing services

Only when approved, perform the target installation and audit:

~~~sh
run_target apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
run_target dpkg --audit
~~~

**Do not** write follow-up commands to mask/disable Docker or containerd, grant the administrator the root-equivalent `docker` group, launch a container, or link Docker into OMV. Package-provided service startup defaults are intentional.

The installer may temporarily suppress maintainer-script service starts through its **native `policy-rc.d`**; this is distinct from permanently disabling services after boot.

## Step 7 — Build and validate this source

Check the module's POSIX syntax:

~~~sh
sh -n installer/profile-docker.sh
~~~

Build via `./build.sh`. In a disposable VM test Docker **unselected**, selected+approved, a declined transaction, invalid repository credentials and first boot. Confirm `docker --version`, `docker compose version` and the Docker/containerd unit states on the installed target. Test OMV + Docker together **without** OMV-Extras or Compose plugin installation.

**Source:** [profile-docker.sh](my-cdd/installer/profile-docker.sh). Its full function is short enough to inspect while following these construction steps.
