#!/usr/bin/env bash

#   =======================================
#   Welcome to Winello!
#   The whole script is divided in different
#   functions to make it easier to read.
#   Feel free to contribute!
#   =======================================

# Wine-osu current versions for update
MAJOR=10
MINOR=15
PATCH=4
WINEVERSION=$MAJOR.$MINOR-$PATCH
LASTWINEVERSION=0

# Other versions for external downloads
DISCRPCBRIDGEVERSION=1.2
GOSUMEMORYVERSION=1.3.9
TOSUVERSION=4.3.1
YAWLVERSION=0.8.2
MAPPINGTOOLSVERSION=1.12.27

# GitHub mirror configuration (override GITHUB_BASE_URL to use a proxy)
DEFAULT_GITHUB_BASE="https://github.com/"
if [ -z "${GITHUB_BASE_URL+x}" ]; then
    GITHUB_BASE_URL="$DEFAULT_GITHUB_BASE"
    GITHUB_MIRROR_SELECTED=0
else
    [ -z "$GITHUB_BASE_URL" ] && GITHUB_BASE_URL="$DEFAULT_GITHUB_BASE"
    GITHUB_MIRROR_SELECTED=1
fi

normalizeGithubBase() {
    case "$GITHUB_BASE_URL" in
        */) ;;
        *) GITHUB_BASE_URL="${GITHUB_BASE_URL}/" ;;
    esac
}

setGithubLinks() {
    WINELINK="${GITHUB_BASE_URL}NelloKudo/WineBuilder/releases/download/wine-osu-staging-${WINEVERSION}/wine-osu-winello-fonts-wow64-${WINEVERSION}-x86_64.tar.xz"
    WINECACHYLINK="${GITHUB_BASE_URL}NelloKudo/WineBuilder/releases/download/wine-osu-cachyos-v10.0-3/wine-osu-cachy-winello-fonts-wow64-10.0-3-x86_64.tar.xz"
    PREFIXLINK="${GITHUB_BASE_URL}NelloKudo/osu-winello/releases/download/winello-bins/osu-winello-prefix.tar.xz"
    OSUMIMELINK="${GITHUB_BASE_URL}NelloKudo/osu-winello/releases/download/winello-bins/osu-mime.tar.gz"
    YAWLLINK="${GITHUB_BASE_URL}whrvt/yawl/releases/download/v${YAWLVERSION}/yawl"
    DISCRPCLINK="${GITHUB_BASE_URL}EnderIce2/rpc-bridge/releases/download/v${DISCRPCBRIDGEVERSION}/bridge.zip"
    GOSUMEMORYLINK="${GITHUB_BASE_URL}l3lackShark/gosumemory/releases/download/${GOSUMEMORYVERSION}/gosumemory_windows_amd64.zip"
    TOSULINK="${GITHUB_BASE_URL}tosuapp/tosu/releases/download/v${TOSUVERSION}/tosu-windows-v${TOSUVERSION}.zip"
    MAPPINGTOOLSLINK="${GITHUB_BASE_URL}OliBomby/Mapping_Tools/releases/download/v${MAPPINGTOOLSVERSION}/mapping_tools_installer_x64.exe"
    WINELLOGIT="${GITHUB_BASE_URL}NelloKudo/osu-winello.git"
}

selectGithubMirror() {
    cat <<EOF
请选择 GitHub 镜像 (按 Enter 为默认的官方 ${DEFAULT_GITHUB_BASE}):
  1) edgeone 全球加速 / 数据统计
  2) cloudflare 主站 (gh-proxy.org)
  3) cloudflare 主站 IPV6 (v6.gh-proxy.org)
  4) 香港优化线路 (hk.gh-proxy.org)
  5) Fastly CDN (cdn.gh-proxy.org)
  0) 不使用镜像 (官方源)
EOF
    printf "输入序号 [默认0]: "
    read -r mirror_choice
    case "$mirror_choice" in
    1) GITHUB_BASE_URL="https://edgeone.gh-proxy.org/${DEFAULT_GITHUB_BASE}" ;;
    2) GITHUB_BASE_URL="https://gh-proxy.org/${DEFAULT_GITHUB_BASE}" ;;
    3) GITHUB_BASE_URL="https://v6.gh-proxy.org/${DEFAULT_GITHUB_BASE}" ;;
    4) GITHUB_BASE_URL="https://hk.gh-proxy.org/${DEFAULT_GITHUB_BASE}" ;;
    5) GITHUB_BASE_URL="https://cdn.gh-proxy.org/${DEFAULT_GITHUB_BASE}" ;;
    *) GITHUB_BASE_URL="$DEFAULT_GITHUB_BASE" ;;
    esac
    normalizeGithubBase
    setGithubLinks
    GITHUB_MIRROR_SELECTED=1
    if [ "$GITHUB_BASE_URL" = "$DEFAULT_GITHUB_BASE" ]; then
        printf "使用官方 GitHub 源。\n"
    else
        printf "GitHub 镜像已切换到: %s\n" "$GITHUB_BASE_URL"
    fi
}

maybeSelectGithubMirror() {
    [ "${USE_CACHED_DEPS:-0}" = "1" ] && return 0
    [ "${GITHUB_MIRROR_SELECTED:-0}" = "1" ] && return 0
    selectGithubMirror
}

normalizeGithubBase
setGithubLinks

# Other download links
WINETRICKSLINK="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" # Winetricks for --fixprefix
OSUDOWNLOADURL="https://m1.ppy.sh/r/osu!install.exe"
AKATSUKILINK="https://air_conditioning.akatsuki.gg/loader"
STEAMRUNTIMELINK="https://repo.steampowered.com/steamrt-images-sniper/snapshots/latest-container-runtime-depot/SteamLinuxRuntime_sniper.tar.xz"

# The directory osu-winello.sh is in
SCRDIR="$(realpath "$(dirname "$0")")"
# The full path to osu-winello.sh
SCRPATH="$(realpath "$0")"
DEPS_CACHE_DIR="${DEPS_CACHE_DIR:-$SCRDIR/deps-cache}"
OSU_WINELLO_REPO_CACHE="${DEPS_CACHE_DIR}/osu-winello.git"
STEAM_RUNTIME_ARCHIVE="${STEAM_RUNTIME_ARCHIVE:-$DEPS_CACHE_DIR/SteamLinuxRuntime_sniper.tar.xz}"

# Exported global variables

export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export BINDIR="${BINDIR:-$HOME/.local/bin}"

OSUPATH="${OSUPATH:-}" # Could either be exported from the osu-wine launcher, from the osuconfig/osupath, or empty at first install (will set up in installOrChangeDir)

# Don't rely on this! We should get the launcher path from `osu-wine --update`, this is a "hack" to support updating from umu
if [ -z "${LAUNCHERPATH}" ]; then
    LAUNCHERPATH="$(realpath /proc/$PPID/exe)" || LAUNCHERPATH="$(readlink /proc/$PPID/exe)"
    [[ ! "${LAUNCHERPATH}" =~ .*osu.* ]] && LAUNCHERPATH=
fi
[ -z "${LAUNCHERPATH}" ] && LAUNCHERPATH="$BINDIR/osu-wine" # If we STILL couldn't find it, just use the default directory

export WINEDLLOVERRIDES="winemenubuilder.exe=;" # Blocks wine from creating .desktop files
export WINEDEBUG="-wineboot,${WINEDEBUG:-}"     # Don't show "failed to start winemenubuilder"

export WINENTSYNC="${WINENTSYNC:-0}" # Don't use these for setup-related stuff to be safe
export WINEFSYNC="${WINEFSYNC:-0}"   # (still, don't override launcher settings, because if wineserver is running with different settings, it will fail to start)
export WINEESYNC="${WINEESYNC:-0}"

# Other shell local variables
WINETRICKS="${WINETRICKS:-"$XDG_DATA_HOME/osuconfig/winetricks"}"
YAWL_INSTALL_PATH="${YAWL_INSTALL_PATH:-"$XDG_DATA_HOME/osuconfig/yawl"}"
export WINE="${WINE:-"${YAWL_INSTALL_PATH}-winello"}"
export WINESERVER="${WINESERVER:-"${WINE}server"}"
export WINEPREFIX="${WINEPREFIX:-"$XDG_DATA_HOME/wineprefixes/osu-wineprefix"}"
export WINE_INSTALL_PATH="${WINE_INSTALL_PATH:-"$XDG_DATA_HOME/osuconfig/wine-osu"}"

# Make all paths visible to pressure-vessel
[ -z "${PRESSURE_VESSEL_FILESYSTEMS_RW}" ] && {
    _mountline="$(df -P "$SCRPATH" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _mainscript_mount="${_mountline##* }:"  # mountpoint to main script path
    _mountline="$(df -P "$LAUNCHERPATH" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _curdir_mount="${_mountline##* }:" # mountpoint to current directory
    _mountline="$(df -P "$XDG_DATA_HOME" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _home_mount="${_mountline##* }:"  # mountpoint to XDG_DATA_HOME
    PRESSURE_VESSEL_FILESYSTEMS_RW+="${_mainscript_mount:-}${_curdir_mount:-}${_home_mount:-}/mnt:/media:/run/media"
    [ -r "$XDG_DATA_HOME/osuconfig/osupath" ] && OSUPATH=$(</"$XDG_DATA_HOME/osuconfig/osupath") &&
        PRESSURE_VESSEL_FILESYSTEMS_RW+=":$(realpath "$OSUPATH"):$(realpath "$OSUPATH"/Songs 2>/dev/null)" # mountpoint to osu/songs directory
    export PRESSURE_VESSEL_FILESYSTEMS_RW="${PRESSURE_VESSEL_FILESYSTEMS_RW//\/:/:}"                       # clean any "just /" mounts, pressure-vessel doesn't like that
}

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#   =====================================
#   =====================================
#           INSTALLER FUNCTIONS
#   =====================================
#   =====================================

# Simple echo function (but with cool text e.e)
Info() {
    echo -e '\033[1;34m'"Winello:\033[0m $*"
}

Warning() {
    echo -e '\033[0;33m'"Winello (WARNING):\033[0m $*"
}

# Function to quit the install but not revert it in some cases
Quit() {
    echo -e '\033[1;31m'"Winello:\033[0m $*"
    exit 1
}

# Function to revert the install in case of any type of fail
Revert() {
    echo -e '\033[1;31m'"Reverting install...:\033[0m"
    rm -f "$XDG_DATA_HOME/icons/osu-wine.png"
    rm -f "$XDG_DATA_HOME/applications/osu-wine.desktop"
    rm -f "$BINDIR/osu-wine"
    rm -rf "$XDG_DATA_HOME/osuconfig"
    rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"
    rm -f "/tmp/osu-mime.tar.xz"
    rm -rf "/tmp/osu-mime"
    rm -f "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop"
    rm -f "/tmp/winestreamproxy-2.0.3-amd64.tar.xz"
    rm -rf "/tmp/winestreamproxy"
    echo -e '\033[1;31m'"Reverting done, try again with ./osu-winello.sh\033[0m"
    exit 1
}

# Error function pointing at Revert(), but with an appropriate message
InstallError() {
    echo -e '\033[1;31m'"Script failed:\033[0m $*"
    Revert
}

# Error function for other features besides install
Error() {
    echo -e '\033[1;31m'"Script failed:\033[0m $*"
    return 0 # don't exit, handle errors ourselves, propagate result to launcher if needed
}

# Shorthand for a lot of functions succeeding
okay="eval Info Done! && return 0"

cachePathForUrl() {
    local url="$1"
    local filename="${url##*/}"
    [ -z "$filename" ] && filename="cached-dependency"
    echo "$DEPS_CACHE_DIR/$filename"
}

wgetcommand="wget -q --show-progress"
_wget() {
    local url="$1"
    local output="$2"
    $wgetcommand "$url" -O "$output" && return 0
    { [ $? = 2 ] && wgetcommand="wget"; } || wgetcommand="wget --no-check-certificate"
    $wgetcommand "$url" -O "$output" && return 0
    wgetcommand='' # broken, use curl from now on
    return 1
}

DownloadFile() {
    local url="$1"
    local output="$2"
    local cachefile
    cachefile="$(cachePathForUrl "$url")"

    if [ "${USE_CACHED_DEPS:-0}" = "1" ]; then
        if [ -s "$cachefile" ]; then
            Info "Using cached $1 from $cachefile"
            cp "$cachefile" "$output"
            return 0
        fi
        Error "Cached dependency not found for $url. Run ./osu-winello.sh --download-deps first."
        return 1
    fi

    Info "Downloading $1 to $2..."
    if [ -n "$wgetcommand" ] && command -v wget >/dev/null 2>&1; then
        _wget "$url" "$output" && {
            [ "$output" != "$cachefile" ] && { mkdir -p "$DEPS_CACHE_DIR" && cp "$output" "$cachefile" 2>/dev/null; }
            return 0
        }
    fi # fall through to curl
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$url" -o "$output" && {
            [ "$output" != "$cachefile" ] && { mkdir -p "$DEPS_CACHE_DIR" && cp "$output" "$cachefile" 2>/dev/null; }
            return 0
        }
    fi
    Error "Failed to download $url. Check your connection."
    return 1
}

cacheOsuWinelloRepo() {
    if ! command -v git >/dev/null 2>&1; then
        Error "git is required to cache the osu-winello repository."
        return 1
    fi

    if [ -d "$OSU_WINELLO_REPO_CACHE" ]; then
        Info "Updating cached osu-winello repository at $OSU_WINELLO_REPO_CACHE"
        git -C "$OSU_WINELLO_REPO_CACHE" fetch --all --prune || return 1
    else
        Info "Caching osu-winello repository..."
        git clone --mirror "${WINELLOGIT}" "$OSU_WINELLO_REPO_CACHE" || return 1
    fi
    return 0
}

downloadDeps() {
    maybeSelectGithubMirror
    mkdir -p "$DEPS_CACHE_DIR"
    local deps=(
        "$WINELINK"
        "$WINECACHYLINK"
        "$YAWLLINK"
        "$PREFIXLINK"
        "$OSUDOWNLOADURL"
        "$OSUMIMELINK"
        "$DISCRPCLINK"
        "$WINETRICKSLINK"
        "$STEAMRUNTIMELINK"
    )
    local dep
    for dep in "${deps[@]}"; do
        DownloadFile "$dep" "$(cachePathForUrl "$dep")" || return 1
    done
    cacheOsuWinelloRepo || return 1
    Info "Dependencies cached at $DEPS_CACHE_DIR"
    return 0
}

# Function looking for basic stuff needed for installation
InitialSetup() {
    # Better to not run the script as root, right?
    if [ "$USER" = "root" ]; then InstallError "Please run the script without root"; fi

    # Checking for previous versions of osu-wine (mine or DiamondBurned's)
    if [ -e /usr/bin/osu-wine ]; then Quit "Please uninstall old osu-wine (/usr/bin/osu-wine) before installing!"; fi
    if [ -e "$BINDIR/osu-wine" ]; then Quit "Please uninstall Winello (osu-wine --remove) before installing!"; fi

    Info "Welcome to the script! Follow it to install osu! 8)"

    # Checking if $BINDIR is in PATH:
    mkdir -p "$BINDIR"
    pathcheck=$(echo "$PATH" | grep -q "$BINDIR" && echo "y")

    # If $BINDIR is not in PATH:
    if [ "$pathcheck" != "y" ]; then

        if grep -q "bash" "$SHELL"; then
            touch -a "$HOME/.bashrc"
            echo "export PATH=$BINDIR:$PATH" >>"$HOME/.bashrc"
        fi

        if grep -q "zsh" "$SHELL"; then
            touch -a "$HOME/.zshrc"
            echo "export PATH=$BINDIR:$PATH" >>"$HOME/.zshrc"
        fi

        if grep -q "fish" "$SHELL"; then
            mkdir -p "$HOME/.config/fish" && touch -a "$HOME/.config/fish/config.fish"
            fish -c fish_add_path "$BINDIR/"
        fi
    fi

    # Well, we do need internet ig...
    if [ -z "${SKIP_NETWORK_CHECKS:-}" ]; then
        Info "Checking for internet connection.."
        ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && ! ping -c 2 baidu.com >/dev/null 2>&1 && InstallError "Please connect to internet before continuing xd. Run the script again"
    else
        Info "Skipping internet connection check (using cached dependencies).."
    fi

    # Looking for dependencies..
    deps=(pgrep realpath wget zenity unzip)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            InstallError "Please install $dep before continuing!"
        fi
    done
}

# Helper to wait for wineserver to close before continuing to a next step, reduces the chance of flakiness
# Don't return failure, it's probably harmless, unrelated, or unreliable to use as a success indicator (besides specific cases)
waitWine() {
    {
        "$WINESERVER" -w
        "$WINE" "${@:-"--version"}"
    }
    return 0
}

# Function to install script files, yawl and Wine-osu
InstallWine() {
    maybeSelectGithubMirror
    # Installing game launcher and related...
    Info "Installing game script:"
    cp "${SCRDIR}/osu-wine" "$BINDIR/osu-wine" && chmod +x "$BINDIR/osu-wine"

    Info "Installing icons:"
    mkdir -p "$XDG_DATA_HOME/icons"
    cp "${SCRDIR}/stuff/osu-wine.png" "$XDG_DATA_HOME/icons/osu-wine.png" && chmod 644 "$XDG_DATA_HOME/icons/osu-wine.png"

    Info "Installing .desktop:"
    mkdir -p "$XDG_DATA_HOME/applications"
    echo "[Desktop Entry]
Name=osu!
Comment=osu! - Rhythm is just a *click* away!
Type=Application
Exec=$BINDIR/osu-wine %U
Icon=$XDG_DATA_HOME/icons/osu-wine.png
Terminal=false
Categories=Wine;Game;" | tee "$XDG_DATA_HOME/applications/osu-wine.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osu-wine.desktop"

    if [ -d "$XDG_DATA_HOME/osuconfig" ]; then
        Info "Skipping osuconfig.."
    else
        mkdir "$XDG_DATA_HOME/osuconfig"
    fi

    Info "Installing Wine-osu:"
    # Downloading Wine..
    DownloadFile "$WINELINK" "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" || InstallError "Couldn't download wine-osu."

    # This will extract Wine-osu and set last version to the one downloaded
    tar -xf "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
    LASTWINEVERSION="$WINEVERSION"
    rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"

    # Install and verify yawl ASAP, the wrapper mode does not download/install the runtime if no arguments are passed
    installYawl || Revert

    # The update function works under this folder: it compares variables from files stored in osuconfig
    # with latest values from GitHub and check whether to update or not
    Info "Installing script copy for updates.."
    mkdir -p "$XDG_DATA_HOME/osuconfig/update"
    (
        cd "$SCRDIR" || exit 1
        if [ -z "${OFFLINE_INSTALL:-}" ] && [ "${USE_CACHED_DEPS:-0}" != "1" ]; then
            { git clone . "$XDG_DATA_HOME/osuconfig/update" || git clone "${WINELLOGIT}" "$XDG_DATA_HOME/osuconfig/update"; }
        else
            git clone . "$XDG_DATA_HOME/osuconfig/update"
        fi
    ) || InstallError "Git failed, check your connection.."

    git -C "$XDG_DATA_HOME/osuconfig/update" remote set-url origin "${WINELLOGIT}"

    echo "$LASTWINEVERSION" >>"$XDG_DATA_HOME/osuconfig/wineverupdate"
}

# Function configuring folders to install the game
InitialOsuInstall() {
    local installpath=1
    Info "Where do you want to install the game?:
          1 - Default path ($XDG_DATA_HOME/osu-wine)
          2 - Custom path"
    read -r -p "$(Info "Choose your option: ")" installpath

    case "$installpath" in
    '2')
        installOrChangeDir || return 1
        ;;
    *)
        Info "Installing to default.. ($XDG_DATA_HOME/osu-wine)"
        installOrChangeDir "$XDG_DATA_HOME/osu-wine" || return 1
        ;;
    esac
    $okay
}

# Here comes the real Winello 8)
# What the script will install, in order, is:
# - osu!mime and osu!handler to properly import skins and maps
# - Wineprefix
# - Regedit keys to integrate native file manager with Wine
# - rpc-bridge for Discord RPC (flatpak users, google "flatpak discord rpc")
FullInstall() {
    # Time to install my prepackaged Wineprefix, which works in most cases
    # The script is still bundled with osu-wine --fixprefix, which should do the job for me as well

    mkdir -p "$XDG_DATA_HOME/osuconfig/configs" # make the configs directory and copy the example if it doesnt exist
    [ ! -r "$XDG_DATA_HOME/osuconfig/configs/example.cfg" ] && cp "${SCRDIR}/stuff/example.cfg" "$XDG_DATA_HOME/osuconfig/configs/example.cfg"

    Info "Configuring Wineprefix:"

    # Variable to check if download finished properly
    local failprefix="false"
    mkdir -p "$XDG_DATA_HOME/wineprefixes"
    if [ -r "$XDG_DATA_HOME/wineprefixes/osu-wineprefix/system.reg" ]; then
        Info "Wineprefix already exists; do you want to reinstall it?"
        Warning "HIGHLY RECOMMENDED UNLESS YOU KNOW WHAT YOU'RE DOING!"
        read -r -p "$(Info "Choose (y/N): ")" prefchoice
        if [ "$prefchoice" = 'y' ] || [ "$prefchoice" = 'Y' ]; then
            rm -rf "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
        fi
    fi

    # So if there's no prefix (or the user wants to reinstall):
    if [ ! -r "$XDG_DATA_HOME/wineprefixes/osu-wineprefix/system.reg" ]; then
        # Downloading prefix in temporary ~/.winellotmp folder
        # to make up for this issue: see osu-winello issue #36
        mkdir -p "$HOME/.winellotmp"
        DownloadFile "${PREFIXLINK}" "$HOME/.winellotmp/osu-winello-prefix.tar.xz" || Revert

        # Checking whether to create prefix manually or install it from repos
        if [ "$failprefix" = "true" ]; then
            reconfigurePrefix nowinepath fresh || Revert
        else
            tar -xf "$HOME/.winellotmp/osu-winello-prefix.tar.xz" -C "$XDG_DATA_HOME/wineprefixes"
            mv "$XDG_DATA_HOME/wineprefixes/osu-prefix" "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
            reconfigurePrefix nowinepath || Revert
        fi
        # Cleaning..
        rm -rf "$HOME/.winellotmp"
    fi

    # Now set up desktop files and such, no matter whether its a new or old prefix
    osuHandlerSetup || Revert

    Info "Configure and install osu!"
    InitialOsuInstall || Revert

    Info "Installation is completed! Run 'osu-wine' to play osu!"
    Warning "If 'osu-wine' doesn't work, just close and relaunch your terminal."
    exit 0
}

#   =====================================
#   =====================================
#          POST-INSTALL FUNCTIONS
#   =====================================
#   =====================================

longPathsFix() {
    Info "Applying fix for long song names (e.g. because of deeply nested osu! folder)..."

    rm -rf "$WINEPREFIX/dosdevices"
    rm -rf "$WINEPREFIX/drive_c/users/nellokudo"
    mkdir -p "$WINEPREFIX/dosdevices"
    ln -s "$WINEPREFIX/drive_c/" "$WINEPREFIX/dosdevices/c:"
    ln -s / "$WINEPREFIX/dosdevices/z:"
    ln -s "$OSUPATH" "$WINEPREFIX/dosdevices/d:" 2>/dev/null # it's fine if this fails on a fresh install
    waitWine wineboot -u
    return 0
}

saveOsuWinepath() {
    local osupath="${OSUPATH}"
    if [ -z "${osupath}" ]; then
        { [ -r "$XDG_DATA_HOME/osuconfig/osupath" ] && osupath=$(<"$XDG_DATA_HOME/osuconfig/osupath"); } || {
            Error "Can't find the osu! path!" && return 1
        }
    fi

    Info "Saving a copy of the osu! path..."

    PRESSURE_VESSEL_FILESYSTEMS_RW="$(realpath "$osupath"):$(realpath "$osupath"/Songs 2>/dev/null):${PRESSURE_VESSEL_FILESYSTEMS_RW}"
    export PRESSURE_VESSEL_FILESYSTEMS_RW

    local temp_winepath
    temp_winepath="$(waitWine winepath -w "$osupath")"
    [ -z "${temp_winepath}" ] && Error "Couldn't get the osu! path from winepath... Check $osupath/osu!.exe ?" && return 1

    echo -n "${temp_winepath}" >"$XDG_DATA_HOME/osuconfig/.osu-path-winepath"
    echo -n "${temp_winepath}osu!.exe" >"$XDG_DATA_HOME/osuconfig/.osu-exe-winepath"
    $okay
}

deleteFolder() {
    local folder="${1}"
    Info "Do you want to remove the previous install at ${folder}?"
    read -r -p "$(Info "Choose your option (y/N): ")" dirchoice

    if [ "$dirchoice" = 'y' ] || [ "$dirchoice" = 'Y' ]; then
        read -r -p "$(Info "Are you sure? This will delete your osu! files! (y/N)")" dirchoice2
        if [ "$dirchoice2" = 'y' ] || [ "$dirchoice2" = 'Y' ]; then
            rm -rf "${folder}" || { Error "Couldn't remove folder!" && return 1; }
            return 0
        fi
    fi
    Info "Skipping.."
    return 0
}

# Handle `osu-wine --changedir` and installation setup
installOrChangeDir() {
    local newdir="${1:-}"
    local lastdir="${OSUPATH:-}"
    if [ -z "${newdir}" ]; then
        Info "Please choose your osu! directory:"
        newdir="$(zenity --file-selection --directory)"
        [ ! -d "$newdir" ] && { Error "No folder selected, please make sure zenity is installed.." && return 1; }
    fi

    [ ! -s "$newdir/osu!.exe" ] && newdir="$newdir/osu!" # Make it a subdirectory unless osu!.exe is already there
    if [ -s "$newdir/osu!.exe" ] || [ "$newdir" = "$lastdir" ]; then
        Info "The osu! installation already exists..."
    else
        mkdir -p "$newdir"
        DownloadFile "${OSUDOWNLOADURL}" "$newdir/osu!.exe" || return 1

        [ -n "${lastdir}" ] && { deleteFolder "$lastdir" || return 1; }
    fi

    echo "${newdir}" >"$XDG_DATA_HOME/osuconfig/osupath" # Save it for later
    export OSUPATH="${newdir}"

    longPathsFix || return 1
    saveOsuWinepath || return 1
    Info "osu! installed to '$newdir'!"
    return 0
}

reconfigurePrefix() {
    local freshprefix=''
    local nowinepath=''
    while [[ $# -gt 0 ]]; do
        case "${1}" in
        'nowinepath')
            nowinepath=1
            ;;
        'fresh')
            freshprefix=1
            ;;
        *) ;;
        esac
        shift
    done

    installWinetricks

    [ -n "${freshprefix}" ] && {
        Info "Checking for internet connection.." # The bundled prefix install already checks for internet, so no point checking again
        ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && { Error "Please connect to internet before continuing xd. Run the script again" && return 1; }

        [ -d "${WINEPREFIX:?}" ] && rm -rf "${WINEPREFIX}"

        Info "Downloading and installing a new prefix with winetricks. This might take a while, so go make a coffee or something."
        "$WINESERVER" -k
        PATH="${SCRDIR}/stuff:${PATH}" WINEDEBUG="fixme-winediag,${WINEDEBUG:-}" WINENTSYNC=0 WINEESYNC=0 WINEFSYNC=0 \
            "$WINETRICKS" -q nocrashdialog autostart_winedbg=disabled dotnet48 dotnet20 gdiplus_winxp meiryo dxvk win10 ||
            { Error "winetricks failed catastrophically!" && return 1; }
    }

    folderFixSetup || return 1
    discordRpc || return 1

    # save the osu winepath with the new folder, unless its a first-time install (need to install osu first)
    [ -z "${nowinepath}" ] && { saveOsuWinepath || return 1; }

    $okay
}

# Remember whether the user wants to overwrite their local files
askConfirmTimeout() {
    [ -z "${1:-}" ] && Info "Missing an argument for ${FUNCNAME[0]}!?" && exit 1

    local rememberfile="${XDG_DATA_HOME}/osuconfig/rememberupdatechoice"
    touch "${rememberfile}"

    local lastchoice
    lastchoice="$(grep "${1}" "${rememberfile}" | grep -Eo '(y|n)' | tail -n 1)"

    if [ -n "$lastchoice" ] && [ "$lastchoice" = "n" ]; then
        Info "Won't update ${1}, using saved choice from ${rememberfile}"
        Info "Remove this file if you've changed your mind."
        return 1
    elif [ -n "$lastchoice" ] && [ "$lastchoice" = "y" ]; then
        Info "Will update ${1}, using saved choice from ${rememberfile}"
        Info "Remove this file if you've changed your mind."
        return 0
    fi

    local _timeout=${2:-7} # use a 7 second timeout unless manually specified
    echo -n "$(Info "Choose: (Y/n) [${_timeout}s] ")"

    read -t "$_timeout" -r prefchoice

    if [[ "$prefchoice" =~ ^(n|N)(o|O)?$ ]]; then
        Info "Okay, won't update ${1}, saving this choice to ${rememberfile}."
        echo "${1} n" >>"${rememberfile}"
        return 1
    fi
    Info "Will update ${1}, saving this choice to ${rememberfile}."
    echo "${1} y" >>"${rememberfile}"
    echo ""
    return 0
}

# A helper for updating the osu-wine launcher itself
launcherUpdate() {
    local launcher="${1}"
    local update_source="$XDG_DATA_HOME/osuconfig/update/osu-wine"
    local backup_path="$XDG_DATA_HOME/osuconfig/osu-wine.bak"

    if [ ! -f "$update_source" ]; then
        Warning "Update source not found: $update_source"
        return 1
    fi

    if ! cp -f "$launcher" "$backup_path"; then
        Warning "Failed to create backup at $backup_path"
        return 1
    fi

    if ! cp -f "$update_source" "$launcher"; then
        Warning "Failed to apply update to $launcher"
        Warning "Attempting to restore from backup..."

        if ! cp -f "$backup_path" "$launcher"; then
            Warning "Failed to restore backup - system may be in inconsistent state"
            Warning "Manual restoration required from: $backup_path"
            return 1
        fi
        return 1
    fi

    if ! chmod --reference="$backup_path" "$launcher" 2>/dev/null; then
        chmod +x "$launcher" 2>/dev/null || {
            Warning "Failed to set executable permissions on $launcher"
            return 1
        }
    fi
    $okay
}

extractSteamRuntimeForYawl() {
    local dest_dir
    dest_dir="${XDG_DATA_HOME}/yawl"
    local runtime_dir="$dest_dir/SteamLinuxRuntime_sniper"

    if [ ! -s "$STEAM_RUNTIME_ARCHIVE" ]; then
        Error "Steam runtime archive not found at $STEAM_RUNTIME_ARCHIVE"
        return 1
    fi

    if [ -d "$runtime_dir" ]; then
        Info "Steam runtime already extracted at $runtime_dir, skipping manual extraction."
        return 0
    fi

    Info "Extracting SteamLinuxRuntime_sniper.tar.xz into $dest_dir..."
    mkdir -p "$dest_dir"
    tar -xf "$STEAM_RUNTIME_ARCHIVE" -C "$dest_dir" || { Error "Failed to extract SteamLinuxRuntime_sniper.tar.xz" && return 1; }
    return 0
}

installYawl() {
    Info "Installing yawl..."
    DownloadFile "$YAWLLINK" "/tmp/yawl" || return 1
    mv "/tmp/yawl" "$XDG_DATA_HOME/osuconfig"
    chmod +x "$YAWL_INSTALL_PATH"

    if [ -n "${OFFLINE_INSTALL:-}" ] || [ "${USE_CACHED_DEPS:-0}" = "1" ]; then
        extractSteamRuntimeForYawl || return 1
    fi

    # Also setup yawl here, this will be required anyways when updating from umu-based osu-wine versions
    YAWL_VERBS="make_wrapper=winello;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    if [ -z "${OFFLINE_INSTALL:-}" ]; then
        YAWL_VERBS="update;verify;exec=/bin/true" "$YAWL_INSTALL_PATH" || { Error "There was an error setting up yawl!" && return 1; }
    else
        Info "Offline install detected, skipping yawl update step."
        YAWL_VERBS="verify;exec=/bin/true" "$YAWL_INSTALL_PATH" || { Error "There was an error setting up yawl!" && return 1; }
    fi
    $okay
}

# This function reads files located in $XDG_DATA_HOME/osuconfig
# to see whether a new wine-osu version has been released.
Update() {
    local launcher_path="${1:-"${LAUNCHERPATH}"}"
    if [ ! -x "$WINE" ]; then
        rm -f "${XDG_DATA_HOME}/osuconfig/rememberupdatechoice"
        installYawl || Info "Continuing, but things might be broken..."
    else
        local INSTALLED_YAWL_VERSION
        INSTALLED_YAWL_VERSION="$(env "YAWL_VERBS=version" "$WINE" 2>/dev/null)"
        if [[ "$INSTALLED_YAWL_VERSION" =~ 0\.5\.* ]]; then
            installYawl || Info "Continuing, but things might be broken..."
        else
            Info "Checking for yawl updates..."
            YAWL_VERBS="update" "$WINE" "--version"
        fi
    fi

    # Reading the last version installed
    [ -r "$XDG_DATA_HOME/osuconfig/wineverupdate" ] && LASTWINEVERSION=$(</"$XDG_DATA_HOME/osuconfig/wineverupdate")

    if [ "$LASTWINEVERSION" \!= "$WINEVERSION" ]; then
        # Downloading Wine..
        DownloadFile "$WINELINK" "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" || return 1

        # This will extract Wine-osu and set last version to the one downloaded
        Info "Updating Wine-osu"...
        rm -rf "$XDG_DATA_HOME/osuconfig/wine-osu"
        tar -xf "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
        rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"

        echo "$WINEVERSION" >"$XDG_DATA_HOME/osuconfig/wineverupdate"
        Info "Update is completed!"
        waitWine wineboot -u
    else
        Info "Your Wine-osu is already up-to-date!"
    fi

    mkdir -p "$XDG_DATA_HOME/osuconfig/configs" # make the configs directory and copy the example if it doesnt exist
    [ ! -r "$XDG_DATA_HOME/osuconfig/configs/example.cfg" ] && cp "${SCRDIR}/stuff/example.cfg" "$XDG_DATA_HOME/osuconfig/configs/example.cfg"

    # Will be required when updating from umu-launcher
    [ ! -r "$XDG_DATA_HOME/osuconfig/.osu-path-winepath" ] && { saveOsuWinepath || return 1; }

    [ -n "$NOLAUNCHERUPDATE" ] && Info "Your osu-wine launcher will be left alone." && $okay

    [ ! -x "${launcher_path}" ] && { Error "Can't find the path to the osu-wine launcher to update it. Please reinstall osu-winello." && return 1; }

    if [ ! -w "${launcher_path}" ]; then
        Warning "Note: ${launcher_path} is not writable - updating the osu-wine launcher will not be possible"
        Warning "Try running the update with appropriate permissions if you want to update the launcher,"
        Warning "   or move it to a place like $BINDIR and then run it from there."
        return 0
    fi

    Info "Updating the launcher (${launcher_path})..."
    if launcherUpdate "${launcher_path}"; then
        Info "Launcher update successful!"
        Info "Backup saved to: $XDG_DATA_HOME/osuconfig/osu-wine.bak"
    else
        Error "Launcher update failed" && return 1
    fi
    $okay
}

# Well, simple function to install the game (also implement in osu-wine --remove)
Uninstall() {
    Info "Uninstalling icons:"
    rm -f "$XDG_DATA_HOME/icons/osu-wine.png"

    Info "Uninstalling .desktop:"
    rm -f "$XDG_DATA_HOME/applications/osu-wine.desktop"

    Info "Uninstalling game script, utilities & folderfix:"
    rm -f "$BINDIR/osu-wine"
    rm -f "$BINDIR/folderfixosu"
    rm -f "$BINDIR/folderfixosu.vbs"
    rm -f "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop"

    Info "Uninstalling wine-osu:"
    rm -rf "$XDG_DATA_HOME/osuconfig/wine-osu"

    Info "Uninstalling yawl and the steam runtime:"
    rm -rf "$XDG_DATA_HOME/yawl"

    read -r -p "$(Info "Do you want to uninstall Wineprefix? (y/N)")" wineprch

    if [ "$wineprch" = 'y' ] || [ "$wineprch" = 'Y' ]; then
        rm -rf "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
    else
        Info "Skipping.."
    fi

    read -r -p "$(Info "Do you want to uninstall game files? (y/N)")" choice

    if [ "$choice" = 'y' ] || [ "$choice" = 'Y' ]; then
        read -r -p "$(Info "Are you sure? This will delete your files! (y/N)")" choice2

        if [ "$choice2" = 'y' ] || [ "$choice2" = 'Y' ]; then
            Info "Uninstalling game:"
            if [ -e "$XDG_DATA_HOME/osuconfig/osupath" ]; then
                OSUUNINSTALLPATH=$(<"$XDG_DATA_HOME/osuconfig/osupath")
                rm -rf "$OSUUNINSTALLPATH"
                rm -rf "$XDG_DATA_HOME/osuconfig"
            else
                rm -rf "$XDG_DATA_HOME/osuconfig"
            fi
        else
            rm -rf "$XDG_DATA_HOME/osuconfig"
            Info "Exiting.."
        fi
    else
        rm -rf "$XDG_DATA_HOME/osuconfig"
    fi

    Info "Uninstallation completed!"
    return 0
}

SetupReader() {
    local READER_NAME="${1}"
    Info "Setting up $READER_NAME wrapper..."
    # get all the required paths first
    local READER_PATH
    local OSU_WINEDIR
    local OSU_WINEEXE
    READER_PATH="$(WINEDEBUG=-all "$WINE" winepath -w "$XDG_DATA_HOME/osuconfig/$READER_NAME/$READER_NAME.exe" 2>/dev/null)" || { Error "Didn't find $READER_NAME in the expected location..." && return 1; }
    { [ -r "$XDG_DATA_HOME/osuconfig/.osu-path-winepath" ] && read -r OSU_WINEDIR <<<"$(cat "$XDG_DATA_HOME/osuconfig/.osu-path-winepath")" &&
        [ -r "$XDG_DATA_HOME/osuconfig/.osu-exe-winepath" ] && read -r OSU_WINEEXE <<<"$(cat "$XDG_DATA_HOME/osuconfig/.osu-exe-winepath")"; } ||
        { Error "You need to fully install osu-winello before trying to set up $READER_NAME.\n\t(Missing $XDG_DATA_HOME/osuconfig/.osu-path-winepath or .osu-exe-winepath .)" && return 1; }

    # launcher batch file to open tosu/gosumemory together with osu in the container, and tries to stop hung gosumemory/tosu process when osu! exits (why does that happen!?)
    cat >"$OSUPATH/launch_with_memory.bat" <<EOF
@echo off
set NODE_SKIP_PLATFORM_CHECK=1
cd /d "$OSU_WINEDIR"
start "" osu!.exe %*
start /b "" "$READER_PATH"

:loop
tasklist | find "osu!.exe" >nul
if ERRORLEVEL 1 (
    taskkill /F /IM $READER_NAME.exe
    taskkill /F /IM ${READER_NAME}_overlay.exe
    wineboot -e -f
    exit
)
ping -n 5 127.0.0.1 >nul
goto loop
EOF

    Info "$READER_NAME wrapper enabled. Launch osu! normally to use it!"
    return 0
}

# Simple function that downloads Gosumemory!
Gosumemory() {
    if [ ! -d "$XDG_DATA_HOME/osuconfig/gosumemory" ]; then
        Info "Downloading gosumemory.."
        mkdir -p "$XDG_DATA_HOME/osuconfig/gosumemory"
        DownloadFile "${GOSUMEMORYLINK}" "/tmp/gosumemory.zip" || return 1
        unzip -d "$XDG_DATA_HOME/osuconfig/gosumemory" -q "/tmp/gosumemory.zip"
        rm "/tmp/gosumemory.zip"
    fi
    SetupReader "gosumemory" || return 1
    $okay
}

tosu() {
    if [ ! -d "$XDG_DATA_HOME/osuconfig/tosu" ]; then
        Info "Downloading tosu.."
        mkdir -p "$XDG_DATA_HOME/osuconfig/tosu"
        DownloadFile "${TOSULINK}" "/tmp/tosu.zip" || return 1
        unzip -d "$XDG_DATA_HOME/osuconfig/tosu" -q "/tmp/tosu.zip"
        rm "/tmp/tosu.zip"
    fi
    SetupReader "tosu" || return 1
    $okay
}

# Installs Akatsuki patcher (https://akatsuki.gg/patcher)
akatsukiPatcher() {
    local AKATSUKI_PATH="$XDG_DATA_HOME/osuconfig/akatsukiPatcher"

    if ! grep -q 'dotnetdesktop6' "$WINEPREFIX/winetricks.log" 2>/dev/null; then
        Info "Akatsuki Patcher needs .NET Desktop Runtime 6, installing it with winetricks..."
        $WINETRICKS -q -f dotnetdesktop6
    fi

    if [ ! -d "$AKATSUKI_PATH" ]; then
        Info "Downloading patcher.."
        mkdir -p "$AKATSUKI_PATH"
        wget --content-disposition -O "$AKATSUKI_PATH/akatsuki_patcher.exe" "$AKATSUKILINK"
    fi

    # Setup usual LaunchOsu settings
    export WINEDEBUG="+timestamp,+pid,+tid,+threadname,+debugstr,+loaddll,+winebrowser,+exec${WINEDEBUG:+,${WINEDEBUG}}"
    WINELLO_LOGS_PATH="${XDG_DATA_HOME}/osuconfig/winello.log"

    Info "Opening $AKATSUKI_PATH/akatsuki_patcher.exe .."
    Info "If the patcher fails to find osu!, click on Locate > My Computer > D:, then press open and launch!"
    Info "The run log is located in ${WINELLO_LOGS_PATH}. Attach this file if you make an issue on GitHub or ask for help on Discord."
    "$WINE" "$AKATSUKI_PATH/akatsuki_patcher.exe" &>>"${WINELLO_LOGS_PATH}" || return 1
    return 0
}

# Installs osu! Mapping Tools (olibomby/mapping_tools)
mappingTools() {
    local MAPPINGTOOLSPATH="${WINEPREFIX}/drive_c/Program Files/Mapping Tools"
    local OSUPID

    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="C:\\dotnet_tmp"
    export DOTNET_ROOT="C:\\Program Files\\dotnet"
    [ ! -d "${WINEPREFIX}/drive_c/dotnet_tmp" ] && mkdir -p "${WINEPREFIX}/drive_c/dotnet_tmp"
    [ ! -d "${WINEPREFIX}/drive_c/Program Files/dotnet" ] && mkdir -p "${WINEPREFIX}/drive_c/Program Files/dotnet"

    # Disable icu.dll to prevent issues
    export WINEDLLOVERRIDES="${WINEDLLOVERRIDES};icu.dll=d"

    if [ ! -d "${MAPPINGTOOLSPATH}" ]; then
        if OSUPID="$(pgrep osu!.exe)"; then Quit "Please close osu! before installing mapping tools for the first time."; fi

        "$WINESERVER" -k

        Info "Setting up regedit for Mapping Tools.."
        waitWine reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Avalon.Graphics" /v DisableHWAcceleration /t REG_DWORD /d 1 /f

        Info "Downloading Mapping Tools, please confirm the installer prompts.."
        DownloadFile "${MAPPINGTOOLSLINK}" /tmp/mapping_tools_installer_x64.exe

        waitWine /tmp/mapping_tools_installer_x64.exe
        rm /tmp/mapping_tools_installer_x64.exe
    fi

    if [ -x "$YAWL_INSTALL_PATH" ] && OSUPID="$(pgrep osu!.exe)"; then
        Info "Launching Mapping Tools.."
        YAWL_VERBS="enter=$OSUPID" "${WINE_INSTALL_PATH}/bin/wine" "$MAPPINGTOOLSPATH/"'Mapping Tools.exe'
    else
        Quit "Please launch osu! before launching Mapping Tools!"
    fi
}

# Installs rpc-bridge for Discord RPC (EnderIce2/rpc-bridge)
discordRpc() {
    Info "Setting up Discord RPC integration..."
    if [ -f "${WINEPREFIX}/drive_c/windows/bridge.exe" ]; then
        Info "rpc-bridge (Discord RPC) is already installed, do you want to reinstall it?"
        askConfirmTimeout "rpc-bridge (Discord RPC)" || return 0
    fi

    # try uninstalling the service first
    waitWine reg delete 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\rpc-bridge' /f &>/dev/null
    local chk

    DownloadFile "${DISCRPCLINK}" "/tmp/bridge.zip" || return 1

    mkdir -p /tmp/rpc-bridge
    unzip -d /tmp/rpc-bridge -q "/tmp/bridge.zip"
    waitWine /tmp/rpc-bridge/bridge.exe --install
    rm -f "/tmp/bridge.zip"
    rm -rf "/tmp/rpc-bridge"
    $okay
}

folderFixSetup() {
    longPathsFix || return 1
    # Integrating native file explorer (inspired by) Maot: https://gist.github.com/maotovisk/1bf3a7c9054890f91b9234c3663c03a2
    # This only involves regedit keys.
    Info "Setting up native file explorer integration..."

    local VBS_PATH="$XDG_DATA_HOME/osuconfig/folderfixosu.vbs"
    local FALLBACK_PATH="$XDG_DATA_HOME/osuconfig/folderfixosu"
    cp "${SCRDIR}/stuff/folderfixosu.vbs" "${VBS_PATH}"
    cp "${SCRDIR}/stuff/folderfixosu" "${FALLBACK_PATH}"

    local VBS_WINPATH
    local fallback
    VBS_WINPATH="$(WINEDEBUG=-all waitWine winepath.exe -w "${VBS_PATH}" 2>/dev/null)" || fallback="1"
    [ -z "$VBS_WINPATH" ] && fallback="1"

    waitWine reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f
    waitWine reg delete "HKEY_CLASSES_ROOT\folder\shell\open\ddeexec" /f
    if [ -z "${fallback:-}" ]; then
        waitWine reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f /ve /t REG_SZ /d "wscript.exe \"${VBS_WINPATH//\\/\\\\}\" \"%1\""
    else
        waitWine reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f /ve /t REG_SZ /d "${FALLBACK_PATH} xdg-open \"%1\""
    fi
    $okay
}

osuHandlerSetup() {
    Info "Configuring osu-mime and osu-handler..."

    # Installing osu-mime from https://aur.archlinux.org/packages/osu-mime
    DownloadFile "${OSUMIMELINK}" "/tmp/osu-mime.tar.gz" || return 1

    tar -xf "/tmp/osu-mime.tar.gz" -C "/tmp"
    mkdir -p "$XDG_DATA_HOME/mime/packages"
    cp "/tmp/osu-mime/osu-file-extensions.xml" "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    update-mime-database "$XDG_DATA_HOME/mime"
    rm -f "/tmp/osu-mime.tar.gz"
    rm -rf "/tmp/osu-mime"

    # Installing osu-handler from openglfreak/osu-handler-wine / https://aur.archlinux.org/packages/osu-handler
    # Binary was compiled from source on Ubuntu 18.04
    chmod +x "$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler-wine"

    # Creating entries for those two
    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=application/x-osu-skin-archive;application/x-osu-replay;application/x-osu-beatmap-archive;
Exec=$BINDIR/osu-wine --osuhandler %f
NoDisplay=true
StartupNotify=true
Icon=$XDG_DATA_HOME/icons/osu-wine.png" | tee "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop" >/dev/null

    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=x-scheme-handler/osu;
Exec=$BINDIR/osu-wine --osuhandler %u
NoDisplay=true
StartupNotify=true
Icon=$XDG_DATA_HOME/icons/osu-wine.png" | tee "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop" >/dev/null
    update-desktop-database "$XDG_DATA_HOME/applications"

    # Fix to importing maps/skins/osu links after Stable update 20250122.1: https://osu.ppy.sh/home/changelog/stable40/20250122.1
    Info "Setting up file (.osz/.osk) and url associations..."

    # Adding the osu-handler.reg file to registry
    waitWine regedit /s "$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler.reg"
    $okay
}

# Open files/links with osu-handler-wine
osuHandlerHandle() {
    local ARG="${*:-}" OSUPID
    local HANDLERRUN=("$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler-wine")
    [ ! -x "${HANDLERRUN[0]}" ] && chmod +x "${HANDLERRUN[0]}"

    if [ -x "$YAWL_INSTALL_PATH" ] && OSUPID="$(pgrep osu!.exe)"; then
        HANDLERRUN=("env" "YAWL_VERBS=enter=$OSUPID" "$YAWL_INSTALL_PATH" "${HANDLERRUN[0]}")
        echo "Trying to open osu-handler-wine in the running container for osu! (PID=$OSUPID)" >&2
    else
        HANDLERRUN=("env" "${WINE}") # we don't actually need osu-handler if we're starting a new instance
        echo "Trying to open a new instance of osu! to handle ${ARG}" >&2
    fi

    case "$ARG" in
    osu://*)
        echo "Trying to load link ($ARG).." >&2
        exec "${HANDLERRUN[@]}" 'C:\\windows\\system32\\start.exe' "$ARG"
        ;;
    *.osr | *.osz | *.osk | *.osz2)
        local EXT="${ARG##*.}" FULLARGPATH FILEDIR
        FULLARGPATH="$(realpath "${ARG}")" || FULLARGPATH="${ARG}" # || for fallback if realpath failed

        # also, add the containing directory to the PRESSURE_VESSEL_FILESYSTEMS_RW, because it might be in some other location
        FILEDIR="$(realpath "$(dirname "${FULLARGPATH}")")"
        if [ -n "${FILEDIR}" ] && [ "${FILEDIR}" != "/" ]; then
            export PRESSURE_VESSEL_FILESYSTEMS_RW="${PRESSURE_VESSEL_FILESYSTEMS_RW}:${FILEDIR}"
        fi

        echo "Trying to load file ($FULLARGPATH).." >&2
        exec "${HANDLERRUN[@]}" 'C:\\windows\\system32\\start.exe' "/ProgIDOpen" "osustable.File.$EXT" "$FULLARGPATH"
        ;;
    esac
    # If we reached here, it must means osu-handler failed/none of the cases matched
    Error "Unsupported osu! file ($ARG) !" >&2
    Error "Try running \"bash $SCRPATH fixosuhandler\" !" >&2
    return 1
}

installWinetricks() {
    if [ ! -x "$WINETRICKS" ]; then
        Info "Installing winetricks..."
        DownloadFile "$WINETRICKSLINK" "/tmp/winetricks" || return 1
        mv "/tmp/winetricks" "$XDG_DATA_HOME/osuconfig"
        chmod +x "$WINETRICKS"
        $okay
    fi
    return 0
}

FixUmu() {
    if [ ! -f "$BINDIR/osu-wine" ] || [ -z "${LAUNCHERPATH}" ]; then
        Error "Looks like you haven't installed osu-winello yet, so you should run ./osu-winello.sh first." && return 1
    fi
    Info "Looks like you're updating from the umu-launcher based osu-wine, so we'll try to run a full update now..."
    Info "Please answer 'yes' when asked to update the 'osu-wine' launcher"

    Update "${LAUNCHERPATH}" || { Error "Updating failed... Please do a fresh install of osu-winello." && return 1; }
    $okay
}

FixYawl() {
    if [ ! -f "$BINDIR/osu-wine" ]; then
        Error "Looks like you haven't installed osu-winello yet, so you should run ./osu-winello.sh first." && return 1
    elif [ ! -f "$YAWL_INSTALL_PATH" ]; then
        Error "yawl not found, you should run ./osu-winello.sh first." && return 1
    fi

    Info "Fixing yawl..."
    if [ -z "${OFFLINE_INSTALL:-}" ]; then
        YAWL_VERBS="update;verify;exec=/bin/true" "$YAWL_INSTALL_PATH" && chk=$?
    else
        Info "Offline install detected, skipping yawl update step."
        YAWL_VERBS="verify;exec=/bin/true" "$YAWL_INSTALL_PATH" && chk=$?
    fi
    YAWL_VERBS="make_wrapper=winello;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    if [ "${chk}" != 0 ]; then
        Error "That didn't seem to work... try again?" && return 1
    else
        Info "yawl should be good to go now."
    fi
    $okay
}

WineCachySetup() {
    # First time setup: yawl-winello-cachy
    if [ ! -d "$XDG_DATA_HOME/osuconfig/wine-osu-cachy-10.0" ]; then
        DownloadFile "$WINECACHYLINK" "/tmp/winecachy.tar.xz"
        tar -xf "/tmp/winecachy.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
        rm -f "/tmp/winecachy.tar.xz"

        WINE_INSTALL_PATH="$XDG_DATA_HOME/osuconfig/wine-osu-cachy-10.0"
        YAWL_VERBS="make_wrapper=winello-cachy;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    fi
}

# Help!
Help() {
    Info "To install the game, run ./osu-winello.sh
          To download dependencies for offline install, run ./osu-winello.sh --download-deps
          To install using cached dependencies, run ./osu-winello.sh install-with-cache
          To uninstall the game, run ./osu-winello.sh uninstall
          To retry installing yawl-related files, run ./osu-winello.sh fixyawl
          You can read more at README.md or ${GITHUB_BASE_URL}NelloKudo/osu-winello"
}

#   =====================================
#   =====================================
#            MAIN SCRIPT
#   =====================================
#   =====================================

case "$1" in
'')
    {
        InitialSetup &&
            InstallWine &&
            FullInstall
    } || exit 1
    ;;

'--download-deps')
    downloadDeps || exit 1
    ;;

'install-with-cache')
    USE_CACHED_DEPS=1
    SKIP_NETWORK_CHECKS=1
    OFFLINE_INSTALL=1
    {
        InitialSetup &&
            InstallWine &&
            FullInstall
    } || exit 1
    ;;

'uninstall')
    Uninstall || exit 1
    ;;

'gosumemory')
    Gosumemory || exit 1
    ;;

'tosu')
    tosu || exit 1
    ;;

'akatsukiPatcher')
    akatsukiPatcher || exit 1
    ;;

'mappingTools')
    mappingTools || exit 1
    ;;

'discordrpc')
    discordRpc || exit 1
    ;;

'fixfolders')
    folderFixSetup || exit 1
    ;;

'fixprefix')
    reconfigurePrefix fresh || exit 1
    ;;

'winecachy-setup')
    WineCachySetup || exit 1
    ;;

# Also catch "fixosuhandler"
*osu*handler)
    osuHandlerSetup || exit 1
    ;;

'handle')
    # Should be called by the osu-handler desktop files (or osu-wine for backwards compatibility)
    osuHandlerHandle "${@:2}" || exit 1
    ;;

'installwinetricks')
    installWinetricks || exit 1
    ;;

'changedir')
    installOrChangeDir || exit 1
    ;;

update*)
    Update "${2:-}" || exit 1 # second argument is the path to the osu-wine launcher, expected to be called by `osu-wine --update`
    ;;

# "umu" kept for backwards compatibility when updating from umu-launcher based osu-wine
*umu*)
    FixUmu || exit 1
    ;;

*yawl*)
    FixYawl || exit 1
    ;;

*help* | '-h')
    Help
    ;;

*)
    Info "Unknown argument(s): ${*}"
    Help
    ;;
esac

# Congrats for reading it all! Have fun playing osu!
# (and if you wanna improve the script, PRs are always open :3)
