# 08 — Recreate the Docker installer profile

**Outcome:** reconstruct a Docker Engine + Compose **optional** module for Debian Installer, including all its inputs and checks. To install Docker on an already running system, use [08 — Docker](../08_docker/README.md).

## Step 1 — Start with the common installer framework

Complete [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md), then work inside `99_custom_netintst/my-cdd/` on a **test branch or scratch copy**. This profile uses `in-target` and native Debconf; it is not a general Debian installation script.

The profile ID is `docker`, its file is `installer/docker.sh`, and its dispatcher function is `profile_docker()`. The first is the checkbox name; the last is the code that actually runs. Docker and [OMV](07_openmediavault.md) both use official signed APT sources and the same shared simulation/default-No approval helpers; their package sets and vendor-specific completion steps remain independent.

## Step 2 — Create each file

| File | Why it exists |
| --- | --- |
| `profiles/docker.description` | The text shown next to the separate Docker checkbox. |
| `profiles/docker.extra` | Makes the Docker module available on the ISO. |
| `profiles/docker.postinst` | Native Simple-CDD completion verifier; checks a marker without rerunning feature installation. |
| `installer/docker.sh` | Full selected-only target Docker installation: prerequisites, HTTPS key, signed repository, complete APT review and audit. |

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

**3. Open `installer/docker.sh`.** Full selected-only target Docker installation: prerequisites, HTTPS key, signed repository, complete APT review and audit.

Open `installer/docker.sh` in a text editor, paste the indicated contents and save it at that path.

The editor opens the file without executing it. Expand the **full listing with the same filename below**, Save the document after reviewing the pasted contents. Do not use an abbreviated snippet instead.




This changes permissions only. The main module is sourced by the confirmed installer dispatcher and should not be launched directly.

Native Debian Installer stage `11my-cdd` runs each approved selected handler **once**, then writes that profile's success marker. Unmodified Simple-CDD stage `14simple-cdd` executes the selected profile's verification-only `.postinst` **in-target**. Stage `15my-cdd-status` independently checks all approved markers and overall `COMPLETE`, returning native exit 10 rather than falsely reporting success.

## Step 3 — Understand the exact installer sequence

1. The `docker` checkbox begins **unchecked**. When chosen, the dispatcher loads this one handler; Docker does not imply OMV or OMV-Extras.
2. The `review_install` helper shows and approves target installation of `ca-certificates` and `curl`, the signing-key prerequisites.
3. The handler downloads Docker's official public key to the target's APT keyring and creates the signed Deb822 repository for **Debian Trixie amd64**.
4. It refreshes the official signed Docker repository and simulates installing **five packages together**: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` and `docker-compose-plugin`.
5. The complete APT plan, including any removals, is shown through the installer Debconf frontend with **default-No** approval. The user decides whether to proceed; no project-defined essential-package blacklist intervenes. The approved set is installed and dpkg audited.
6. It does **not** mask/disable Docker services, create containers, give users the root-equivalent Docker group, or install OMV Compose integrations.

## Step 4 — Check and test the rebuilt files

~~~sh
sh -n installer/docker.sh
~~~

This checks only shell syntax; it does not download Docker.


This parses the selected handler without running it. Verify exact copies using `git hash-object <path>` compared with the original Git blob SHA shown below; the command reads content only.

When the shared framework and other required profile manifests are complete, run `./build.sh`. In a **disposable VM**, test unchecked Docker, selected+approved, refused APT plan, signed repository refresh, installation and first boot. `docker --version` and `docker compose version` prove only the client tools exist; also check Docker/containerd services.

## Complete source listings

Each expandable section below is the exact complete source file to paste into its matching path. No missing helper functions are hidden inside a short excerpt; **shared** helpers are in [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md).
<details>
<summary><strong>profiles/docker.description</strong> — complete file; 1 lines; Git blob <code>925cd79edbfa31c2475ff40380291cd394226372</code></summary>

````text
Docker Engine and Compose; normal Debian service startup at first boot
````

</details>

<details>
<summary><strong>profiles/docker.extra</strong> — complete file; 2 lines; Git blob <code>21936aae190593b35906634128adb0454c3b6e8d</code></summary>

````text
# docker: source assets copied by Simple-CDD (not automatically installed).
installer/docker.sh
````

</details>



<details>
<summary><strong>installer/docker.sh</strong> — complete file; 31 lines; Git blob <code>110db356d9590cd3a12b0211ca0192a19757ceed</code></summary>

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
    # Install through Docker's official signed Debian repository.
    # No custom masking, disabling or starting of Docker/containerd units:
    # preserve the packages' own install-time and first-boot defaults.
    # OMV remains independent; OMV-Extras/Compose is never installed here.
    simulate_target install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    review_plan 'Docker: official packages and normal service defaults' "$WORK/plan"
    run_target apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run_target dpkg --audit
    log 'Docker packages installed; service activation is governed by native package defaults'
}

````

</details>

## Native Simple-CDD completion verifier

Create `profiles/docker.postinst` from the full source below, alongside its `.description` and `.extra` files. The stage-11 runner writes its record after successful handler execution; the original `14simple-cdd` hook runs this verifier in-target without installing the feature twice.

~~~sh
chmod +x profiles/docker.postinst
sh -n profiles/docker.postinst
~~~

The syntax check is read-only. The final `15my-cdd-status` guard also checks this selected profile's record, returning exit 10 if any required record is missing.

<details>
<summary><strong>profiles/docker.postinst</strong> — complete native verifier (11 lines; Git blob <code>339f0fc713f013663b519aaadd3350f5125ce3f6</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-11 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/docker"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'docker'
    exit 1
fi
````

</details>
