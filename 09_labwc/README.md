# 09 — Optional local Wayland session with labwc (manual installation)

**Goal:** add a small, on-demand local GUI (labwc, Firefox ESR, foot, Thunar, Geany and lxpolkit) to a normally installed Debian NAS, without installing a full desktop environment or a display manager. This chapter does **not** modify the custom Simple-CDD installer or create an installer profile.

**Scope and release:** the repository's documented baseline is **Debian 13 (Trixie) with OpenMediaVault 8**. These commands may also work with packages on Debian 14 (Forky), but Debian 14 + OMV 8 is **not** an officially documented OMV 8 combination. Never mix Trixie and Forky APT sources to install a GUI. This guide is optional and follows the base Debian or OMV steps only when you specifically want a graphical session.

**Requirements:** a local text-console login under a normal (non-root) user, an available DRM/KMS graphics device and connected display, and working seat access through an existing logind session or another compatible seat backend. You can **download and edit the files over SSH**, but a normal local labwc desktop does not launch inside SSH merely because the files are present. A truly headless server with no usable local display may need a different remote-display approach.

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

**When OMV will be installed:** OMV's [Debian installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html) rejects detected desktop environments. If both features are desired, complete OMV installation and verify its operation before considering this optional local session; labwc is not a prerequisite for OMV. The existing manual-only GUI scope is unchanged. For OMV-managed services and configuration, see [Chapter 07 — OMV configuration ownership and checks](../07_openmediavault/README.md#omv-8-configuration-ownership-and-post-install-checks).

</td>
</tr>
</table>

## Step 1 — Review the package transaction before installation

Check which commands are already available. These checks change nothing:

~~~sh
command -v labwc
command -v firefox-esr
command -v foot
command -v thunar
command -v geany
command -v lxpolkit
systemctl get-default
~~~

**Selected packages and APT policies:** install **labwc, firefox-esr and foot with Recommends**; install **thunar, geany and lxpolkit without Recommends**. Do **not** install ShellCheck or the geany-plugins metapackage for this setup. APT's Recommends are not mandatory dependencies; selecting them for the first group can bring optional components such as Xwayland, and so will use more disk space than the strict minimum.

First simulate each group **without changing packages**:

~~~sh
sudo apt-get -s --install-recommends install labwc firefox-esr foot
~~~

~~~sh
sudo apt-get -s --no-install-recommends install thunar geany lxpolkit
~~~

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

Read **both** APT plans. Stop if either would remove **openmediavault**, introduce an unwanted display manager (LightDM, GDM, SDDM, etc.), install a competing network manager, unexpectedly upgrade OMV-critical packages or add undesirable system services. The Wayland graphics stack may use logind or seatd; check the actual planned transaction. In particular, **labwc with Recommends may introduce Xwayland**, which is optional for the selected native-Wayland applications. Avoid mixing Debian 13 and 14 sources to satisfy dependencies.

</td>
</tr>
</table>

If and only if each simulation is acceptable, run these **two separate installations**:

~~~sh
sudo apt-get install --install-recommends labwc firefox-esr foot
~~~

~~~sh
sudo apt-get install --no-install-recommends thunar geany lxpolkit
~~~

Do not install a full desktop/task metapackage, a graphical login manager, a separate taskbar or a competing disk-mounting utility for this procedure.

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

**Thunar:** keep **Enable Volume Management** disabled and browse OMV's existing mounts under ordinary user permissions. Avoid installing Thunar's optional volume-management helpers unless needed for a separately approved use case. **Geany:** provides syntax highlighting and IDE-style editing for Bash and configuration files; no ShellCheck or plugins are required for basic editing. **lxpolkit:** only supplies a graphical authentication agent; it does not itself enable privileged Thunar browsing. Its use is described in the optional administrator-access section below.

</td>
</tr>
</table>

## Step 2 — Download the optional labwc menu configuration

The **only configuration file supplied** is [files/menu.xml](files/menu.xml): a right-click desktop menu for **Terminal**, **Firefox ESR**, **Files (Thunar)**, **Geany**, **Running Windows**, **Reconfigure**, and **Exit labwc**. No power-off, reboot, automount, shortcut override or session autostart command is included. No custom `rc.xml` is needed; labwc uses its native/default keybinding behavior.

Use your **normal user** account. The files belong in that user's home directory, **not** in /root or /etc. Create the directory:

~~~sh
mkdir -p "$HOME/.config/labwc"
~~~

Choose **curl or wget**. Download to temporary names so a failed transfer does not overwrite your current configuration.

With curl:

~~~sh
curl -fL --output "$HOME/.config/labwc/menu.xml.new" https://raw.githubusercontent.com/dcf1007/home_server/main/09_labwc/files/menu.xml
~~~

Or with wget (use these **instead** of the curl commands):

~~~sh
wget -O "$HOME/.config/labwc/menu.xml.new" https://raw.githubusercontent.com/dcf1007/home_server/main/09_labwc/files/menu.xml
~~~

Inspect exactly what was downloaded **before** replacing any files:

~~~sh
cat "$HOME/.config/labwc/menu.xml.new"
~~~

Do not proceed if the download failed, is empty, or contains unexpected text. If you already have a custom menu, **read it and merge the required entries rather than replacing it**. The following install step is for a fresh setup or one where replacing the menu is intentional.

Preserve pre-existing files with dated backups, then activate the downloaded files:

~~~sh
if [ -e "$HOME/.config/labwc/menu.xml" ]; then
    cp -a "$HOME/.config/labwc/menu.xml" "$HOME/.config/labwc/menu.xml.backup.$(date +%Y%m%d-%H%M%S)"
fi
mv "$HOME/.config/labwc/menu.xml.new" "$HOME/.config/labwc/menu.xml"
~~~

This affects **only the user-level menu file**. No system service, boot target, network setting, storage mount, keybinding or OMV configuration is edited. The repository's plain XML is downloaded as data; **do not pipe it to a shell**.

## Step 3 — Launch locally when needed

Log in on the machine's **physical text console**, not an SSH-only login, and try:

~~~sh
labwc
~~~

If you get an EGL renderer initialization error (for example **eglInitialize** or **unable to create renderer**), an independently useful fallback is:

~~~sh
WLR_RENDERER=pixman labwc
~~~

This selects Pixman software rendering **for that invocation only**. It was reported to make labwc start on one Debian 14 installation; this is **not** proof of hardware acceleration, Firefox performance or universal device support. Do not modify system-wide environment files merely to use this fallback.

Once inside labwc, **right-click the empty background** for Terminal, Firefox, Files, Geany, Running Windows, Reconfigure and Exit. There is no built-in taskbar, so **minimized windows remain open but hidden**. Restore one using **Alt + Tab** or choose it from the built-in **Running Windows** submenu. This uses labwc's `client-list-combined-menu` (including windows across workspaces), not another panel or daemon. No custom keybinding is supplied. Launch programs from the menu; labwc is not automatically started at boot.

When leaving labwc, use **Exit labwc**. This ends the user's graphical session, not the OMV/NAS services.

If labwc is already running while you replace the XML files, choose **Reconfigure** in the right-click menu (or call **labwc --reconfigure** from a terminal within the session) to load the changes.

## Step 4 — Verify and troubleshoot

Check application commands before trying the corresponding menu entry:

~~~sh
command -v foot
command -v firefox-esr
command -v thunar
command -v geany
command -v lxpolkit
~~~

If a menu entry does nothing, check its application's command first. If the compositor fails to start, review the graphics device, session and logs:

~~~sh
ls -l /dev/dri/
echo "$XDG_SESSION_TYPE"
echo "$XDG_SESSION_ID"
echo "$SSH_CONNECTION"
labwc -d
~~~

The last command starts labwc in diagnostic mode; run it **after exiting** any existing labwc instance and capture its output if needed. Absence of a render device, GPU/Mesa issues and a session without local-seat access can all cause startup problems. Pixman fixes a renderer path, **not** every seat/DRM issue.

Inside Firefox, open **about:support** and inspect **Window Protocol**. The menu requests the Wayland backend using **MOZ_ENABLE_WAYLAND=1**; actual behavior should be verified rather than assumed.

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

If Thunar is installed, keep its volume-management feature disabled, leave NAS disks mounted and configured by OMV, and avoid using the file manager as root. Ordinary file deletion or permission changes can still affect NAS users if your normal account has the corresponding access.

</td>
</tr>
</table>

## Optional: browse administrator-only directories in Thunar

The safest default on an OMV server is to leave Thunar unprivileged and use a terminal with sudo for occasional inspection:

~~~sh
sudo ls -la /root
~~~

If you **specifically require graphical privileged browsing**, Thunar can use the GVfs **admin:///** URI backend (for example, **admin:///root**) after explicit Polkit authorization. This does **not** run the entire Thunar GUI as root, but it **does** permit root-level changes through the authorized backend. It is not read-only.

First check existing packages; inspection makes no changes:

~~~sh
dpkg-query -W gvfs-backends lxpolkit polkitd 2>/dev/null
~~~

On a system missing them, simulate the smallest useful authorization setup:

~~~sh
sudo apt-get -s --no-install-recommends install gvfs-backends
~~~

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

The **gvfs-backends** package is **not part of the selected six-package installation**; it provides the GVfs admin backend as well as additional remote-filesystem and user-session volume-monitor functionality. That additional integration may not fit your OMV isolation policy. The selected **lxpolkit** agent can display authorization prompts but cannot provide the admin backend itself. Carefully review the new APT proposal and any services; install only if privileged GUI browsing is specifically required:

</td>
</tr>
</table>

~~~sh
sudo apt-get install --no-install-recommends gvfs-backends
~~~

Inside the **existing local labwc session**, start the user-level authorization agent from foot if one is not already running:

~~~sh
lxpolkit &
~~~

Then in Thunar press **Ctrl+L**, enter **admin:///root** and authenticate when prompted. You may also try:

~~~sh
thunar admin:///root
~~~

If no prompt appears, check the user-session D-Bus/Polkit agent rather than using \`sudo thunar\` or \`pkexec thunar\`. On Debian 13/14, policy/agent availability and local-session status affect authentication.

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

Do **not** add an always-privileged Thunar shortcut to the menu, loosen permissions recursively, or use this elevated view to change OMV-managed mounts, ACLs, owners or system configuration. For simply reading root-protected files without requiring a GUI, a limited **sudo terminal command** is more conservative.

</td>
</tr>
</table>

**References:** [Debian gvfs-backends package contents](https://packages.debian.org/forky/amd64/gvfs-backends/filelist), [Debian Trixie lxpolkit package](https://packages.debian.org/trixie/lxpolkit), [Polkit privilege-elevation guidance](https://wiki.archlinux.org/title/Privilege_elevation_for_graphical_applications).

## Keep this an optional local session

<table>
<tr>
<td valign="top"><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"></td>
<td valign="top">

Do **not** install or enable a display manager, graphical.target, a competing network manager, a desktop automounter or a power-management daemon for this procedure. The selected lxpolkit agent and the recommended dependency set for labwc/Firefox/foot may still introduce services or startup integration; inspect the actual APT plan and local session before relying on zero changes. No GUI component is added to the Simple-CDD ISO or OpenMediaVault profile. The existing default boot target and OMV-managed network/storage configuration remain the authority for the host.

</td>
</tr>
</table>

**Verification boundary:** repository XML and commands can be checked statically; this is not an end-to-end test on every Debian/OMV combination, GPU or physical machine. Always inspect the live APT plan and test locally.

**References:** [labwc getting started](https://labwc.github.io/getting-started.html), [labwc menu syntax](https://labwc.github.io/labwc-menu.5.html), [labwc configuration](https://labwc.github.io/labwc-config.5.html), [OMV installation requirements](https://docs.openmediavault.org/en/8.x/installation/on_debian.html).
