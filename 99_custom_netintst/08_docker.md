# 08 — Recreate the Docker installer profile

**Outcome:** reconstruct a Docker Engine + Compose **optional** module for Debian Installer, including all its inputs and checks. To install Docker on an already running system, use [08 — Docker](../08_docker/README.md).

## Step 1 — Start with the common installer framework

Complete [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md), then work inside `99_custom_netintst/my-cdd/` on a **test branch or scratch copy**. This profile uses `in-target` and native Debconf; it is not a general Debian installation script.

The profile ID is `docker`, its file is `installer/profile-docker.sh`, and its dispatcher function is `profile_docker()`. The first is the checkbox name; the last is the code that actually runs.

## Step 2 — Create each file

| File | Why it exists |
| --- | --- |
| `profiles/docker.description` | The text shown next to the separate Docker checkbox. |
| `profiles/docker.extra` | Makes the Docker module available on the ISO. |
| `profiles/docker.postinst` | Verifies the Docker completion marker and must be executable. |
| `installer/profile-docker.sh` | Full selected-only target Docker installation: prerequisites, HTTPS key, signed repository, complete APT review and audit. |

Make the folders if needed:

~~~sh
mkdir -p profiles installer
~~~

This creates source directories; it does not install Docker.

**1. Open `profiles/docker.description`.** The text shown next to the separate Docker checkbox.

Open `profiles/docker.description` in a text editor, paste the indicated contents and save it at that path.

The editor opens the file without executing it. Expand the **full listing with the same filename below**, Save the document after reviewing the pasted contents. Do not use an abbreviated snippet instead.

**2. Open `profiles/docker.extra`.** Makes the Docker module available on the ISO.

Open `profiles/docker.extra` in a text editor, paste the indicated contents and save it at that path.

The editor opens the file without executing it. Expand the **full listing with the same filename below**, Save the document after reviewing the pasted contents. Do not use an abbreviated snippet instead.

**3. Open `profiles/docker.postinst`.** Verifies the Docker completion marker and must be executable.

Open `profiles/docker.postinst` in a text editor, paste the indicated contents and save it at that path.

The editor opens the file without executing it. Expand the **full listing with the same filename below**, Save the document after reviewing the pasted contents. Do not use an abbreviated snippet instead.

**4. Open `installer/profile-docker.sh`.** Full selected-only target Docker installation: prerequisites, HTTPS key, signed repository, complete APT review and audit.

Open `installer/profile-docker.sh` in a text editor, paste the indicated contents and save it at that path.

The editor opens the file without executing it. Expand the **full listing with the same filename below**, Save the document after reviewing the pasted contents. Do not use an abbreviated snippet instead.


Make the completion verifier executable:

~~~sh
chmod +x profiles/docker.postinst
~~~

This changes permissions only. The main module is sourced by the confirmed installer dispatcher and should not be launched directly.

## Step 3 — Understand the exact installer sequence

1. The `docker` checkbox begins **unchecked**. When chosen, the dispatcher loads this one handler; Docker does not imply OMV or OMV-Extras.
2. The `review_install` helper shows and approves target installation of `ca-certificates` and `curl`, the signing-key prerequisites.
3. The handler downloads Docker's official public key to the target's APT keyring and creates the signed Deb822 repository for **Debian Trixie amd64**.
4. It verifies the Docker package origin, then simulates installing **five packages together**: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` and `docker-compose-plugin`.
5. The complete plan is shown through the installer Debconf frontend with **default-No** approval. The code rejects removal of essential packages, then installs the approved set and audits dpkg.
6. It does **not** mask/disable Docker services, create containers, give users the root-equivalent Docker group, or install OMV Compose integrations.

## Step 4 — Check and test the rebuilt files

~~~sh
sh -n installer/profile-docker.sh
~~~

This checks only shell syntax; it does not download Docker.

~~~sh
sh -n profiles/docker.postinst
~~~

This parses the verifier without running it. Verify exact copies using `git hash-object <path>` compared with the original Git blob SHA shown below; the command reads content only.

When the shared framework and other required profile manifests are complete, run `./build.sh`. In a **disposable VM**, test unchecked Docker, selected+approved, refused APT plan, official origin checks, installation and first boot. `docker --version` and `docker compose version` prove only the client tools exist; also check Docker/containerd services.

## Complete source listings

Each expandable section below is the exact complete source file to paste into its matching path. No missing helper functions are hidden inside a short excerpt; **shared** helpers are in [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md).
<details>
<summary><strong>profiles/docker.description</strong> — complete file; 1 lines; Git blob <code>925cd79edbfa31c2475ff40380291cd394226372</code></summary>

````text
Docker Engine and Compose; normal Debian service startup at first boot
````

</details>

<details>
<summary><strong>profiles/docker.extra</strong> — complete file; 2 lines; Git blob <code>c76b0e5be771e9dfb7c648c14ed6d3b5e21dfaca</code></summary>

````text
# docker: source assets copied by Simple-CDD (not automatically installed).
installer/profile-docker.sh
````

</details>

<details>
<summary><strong>profiles/docker.postinst</strong> — complete file; 11 lines; Git blob <code>3c612478514a65d79baa19c04344f521a46c287c</code></summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/docker"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'docker'
    exit 1
fi
````

</details>

<details>
<summary><strong>installer/profile-docker.sh</strong> — complete file; 38 lines; Git blob <code>a5a40fb5fe8ad22fcffc879173ab749327dc48b3</code></summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_docker() {
    review_install 'Docker signing prerequisites' ca-certificates curl
    mkdir -p /target/etc/apt/keyrings
    capture in-target curl -fsSL --proto '=https' \
        -o /etc/apt/keyrings/docker.asc https://download.docker.com/linux/debian/gpg ||
        fatal 'Official Docker signing key download failed'
    chmod 644 /target/etc/apt/keyrings/docker.asc
    grep -Fx 'VERSION_CODENAME=trixie' /target/etc/os-release >/dev/null ||
        fatal 'Docker requires installed Debian 13 trixie'
    cat > /target/etc/apt/sources.list.d/docker.sources <<'EOT'
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOT
    update_signed_apt
    for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
        capture in-target apt-cache policy "$pkg" || fatal "Cannot inspect $pkg"
        grep -F 'download.docker.com/linux/debian' "$WORK/output" >/dev/null ||
            fatal "$pkg lacks the official signed Docker repository"
    done
    # Install through Docker's official signed Debian repository.
    # No custom masking, disabling or starting of Docker/containerd units:
    # preserve the packages' own install-time and first-boot defaults.
    # OMV remains independent; OMV-Extras/Compose is never installed here.
    simulate_target install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_critical_removals
    review_plan 'Docker: official packages and normal service defaults' "$WORK/plan"
    run_target apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run_target dpkg --audit
    log 'Docker packages installed; service activation is governed by native package defaults'
}

````

</details>
