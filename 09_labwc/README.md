# 09 — Optional local Wayland session with labwc (manual installation)

**Goal:** add a small, on-demand local GUI (labwc, the foot terminal and optionally Firefox ESR and Thunar) to a normally installed Debian NAS, without installing a desktop environment or a display manager. This chapter does **not** modify the custom Simple-CDD installer or create an installer profile.

**Scope and release:** the repository's documented baseline is **Debian 13 (Trixie) with OpenMediaVault 8**. These commands may also work with packages on Debian 14 (Forky), but Debian 14 + OMV 8 is **not** an officially documented OMV 8 combination. Never mix Trixie and Forky APT sources to install a GUI. This guide is optional and follows the base Debian or OMV steps only when you specifically want a graphical session.

**Requirements:** a local text-console login under a normal (non-root) user, an available DRM/KMS graphics device and connected display, and working seat access through an existing logind session or another compatible seat backend. You can **download and edit the files over SSH**, but a normal local labwc desktop does not launch inside SSH merely because the files are present. A truly headless server with no usable local display may need a different remote-display approach.

## Step 1 — Review the package transaction before installation

Check which commands are already available. These checks change nothing:

~~~sh
command -v labwc
command -v foot
command -v firefox-esr
command -v thunar
systemctl get-default
~~~

Simulate installing labwc, a terminal and a browser. The simulation does not install packages:

~~~sh
sudo apt-get -s --no-install-recommends install labwc foot firefox-esr
~~~

Read the full APT proposal. Stop if it would remove **openmediavault**, introduce a display manager (for example LightDM, GDM, SDDM), install a competing network manager, unexpectedly upgrade core OMV packages or bring in unwanted seat-management services. The Wayland graphics stack may use logind or seatd; check the **actual** package plan rather than assuming no daemon can be involved.

Only if the plan is acceptable, install the packages:

~~~sh
sudo apt-get install --no-install-recommends labwc foot firefox-esr
~~~

This is deliberately **not** a full desktop/task package. You do not need Xorg, Xwayland, Waybar or a graphical login manager for labwc, foot and native-Wayland Firefox to operate.

**Optional file browser:** if desired, simulate and separately install Thunar with no Recommends:

~~~sh
sudo apt-get -s --no-install-recommends install thunar
~~~

Review before approving:

~~~sh
sudo apt-get install --no-install-recommends thunar
~~~

Thunar is optional. Avoid installing its recommended volume-management helpers merely for file browsing. Disable Thunar's **Enable Volume Management** setting; browse OMV mounts as a regular user, and administer NAS disks, shares and permissions through OMV. The supplied menu includes a Files entry; it only works if Thunar is actually installed.

## Step 2 — Download the two optional labwc configuration files

The files in this repository are:

- [files/menu.xml](files/menu.xml): right-click desktop menu for **Terminal**, **Firefox ESR**, **Files (Thunar)**, **Reconfigure**, and **Exit labwc**. No power-off, reboot, automount or session autostart command.
- [files/rc.xml](files/rc.xml): retains labwc's normal shortcuts and explicitly binds **Super (Windows key) + Enter** to **foot**.

Use your **normal user** account. The files belong in that user's home directory, **not** in /root or /etc. Create the directory:

~~~sh
mkdir -p "$HOME/.config/labwc"
~~~

Choose **curl or wget**. Download to temporary names so a failed transfer does not overwrite your current configuration.

With curl:

~~~sh
curl -fL --output "$HOME/.config/labwc/menu.xml.new" https://raw.githubusercontent.com/dcf1007/home_server/main/09_labwc/files/menu.xml
curl -fL --output "$HOME/.config/labwc/rc.xml.new" https://raw.githubusercontent.com/dcf1007/home_server/main/09_labwc/files/rc.xml
~~~

Or with wget (use these **instead** of the curl commands):

~~~sh
wget -O "$HOME/.config/labwc/menu.xml.new" https://raw.githubusercontent.com/dcf1007/home_server/main/09_labwc/files/menu.xml
wget -O "$HOME/.config/labwc/rc.xml.new" https://raw.githubusercontent.com/dcf1007/home_server/main/09_labwc/files/rc.xml
~~~

Inspect exactly what was downloaded **before** replacing any files:

~~~sh
cat "$HOME/.config/labwc/menu.xml.new"
cat "$HOME/.config/labwc/rc.xml.new"
~~~

Do not proceed if either download failed, is empty, or contains unexpected text. If you already have custom menu/shortcut configuration, **read it and merge the required items rather than replacing it**. The following install step is for a fresh setup or one where replacing these two files is intentional.

Preserve pre-existing files with dated backups, then activate the downloaded files:

~~~sh
for f in menu.xml rc.xml; do
    if [ -e "$HOME/.config/labwc/$f" ]; then
        cp -a "$HOME/.config/labwc/$f" "$HOME/.config/labwc/$f.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    mv "$HOME/.config/labwc/$f.new" "$HOME/.config/labwc/$f"
done
~~~

This affects **only these two user-level files**. No system service, target, network setting, storage mount or OMV configuration is edited. The repository's plain XML files are downloaded as data; **do not pipe them to a shell**.

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

Once inside labwc, right-click the empty background for Terminal, Firefox, Files (if installed), Reconfigure and Exit. **Super** is the Windows-logo key; **Super + Enter** should start foot via the supplied rc.xml. Neither component is automatically launched at boot.

When leaving labwc, use **Exit labwc**. This ends the user's graphical session, not the OMV/NAS services.

If labwc is already running while you replace the XML files, choose **Reconfigure** in the right-click menu (or call **labwc --reconfigure** from a terminal within the session) to load the changes.

## Step 4 — Verify and troubleshoot

Check application commands before trying the corresponding menu entry:

~~~sh
command -v foot
command -v firefox-esr
command -v thunar
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

If Thunar is installed, keep its volume-management feature disabled, leave NAS disks mounted and configured by OMV, and avoid using the file manager as root. Ordinary file deletion or permission changes can still affect NAS users if your normal account has the corresponding access.

## Keep this an optional local session

Do **not** install or enable a display manager, graphical.target, a competing network manager, a desktop automounter or a power-management daemon for this procedure. No GUI component is added to the Simple-CDD ISO or OpenMediaVault profile. The existing default boot target and OMV-managed network/storage configuration remain the authority for the host.

**Verification boundary:** repository XML and commands can be checked statically; this is not an end-to-end test on every Debian/OMV combination, GPU or physical machine. Always inspect the live APT plan and test locally.

**References:** [labwc getting started](https://labwc.github.io/getting-started.html), [labwc menu syntax](https://labwc.github.io/labwc-menu.5.html), [labwc configuration](https://labwc.github.io/labwc-config.5.html), [OMV installation requirements](https://docs.openmediavault.org/en/8.x/installation/on_debian.html).
