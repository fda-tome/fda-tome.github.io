#!/bin/sh
# Install and start the Dagger.jl tutorial console on macOS or Linux:
#
#   curl -fsSL https://fda-tome.github.io/sc26/install.sh | sh
#
# It needs only what those systems already have: curl (or wget), tar, and an
# ssh client. Everything goes in one folder, ~/sc26-dagger, except what the
# console itself keeps for SSH: one marked Odo entry in ~/.ssh/config and its
# connection socket in ~/.ssh/control/. The steps:
#   1. the tutorial files, downloaded from GitHub (no git or account needed);
#   2. a private Python, only if no Python 3.9+ is found: it fetches uv
#      (https://docs.astral.sh/uv/), which downloads one, with no admin rights;
#   3. then it starts the console, which asks for your OLCF username, logs in
#      to Odo in this terminal, and opens the page in your browser.
# Run the same command again to update the tutorial files and start again.
# Your results and your exercise/my_cholesky.jl are kept.
#
# Options (environment variables):
#   SC26_HOME  install folder           (default: ~/sc26-dagger)
#   SC26_REF   GitHub branch or tag     (default: heads/fda/experimental-console;
#              for a tag use tags/<name>)
#   SC26_REPO  GitHub repository        (default: JuliaParallel/julia-hpc-tutorial-sc26)
# Console options go after `sh -s --`, e.g.
#   curl -fsSL https://fda-tome.github.io/sc26/install.sh | sh -s -- --no-auto-allocate
set -eu

repo=${SC26_REPO:-JuliaParallel/julia-hpc-tutorial-sc26}
ref=${SC26_REF:-heads/fda/experimental-console}
subdir=02-Parallel-Programming/Dagger
home=${SC26_HOME:-$HOME/sc26-dagger}
tools=$home/.tools

say() { printf '%s\n' "$*"; }
die() { printf 'install: %s\n' "$*" >&2; exit 1; }

fetch() {  # fetch URL FILE
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        die "this needs curl or wget to download the tutorial."
    fi
}

# 1. The console talks to Odo through ssh, which cannot be installed without
#    admin rights, so only check for it.
if ! command -v ssh >/dev/null 2>&1; then
    case $(uname) in
        Darwin) die "no ssh client found. macOS includes one; check that /usr/bin is on your PATH." ;;
        *)      die "no ssh client found. Install it, then run this again:
  Debian/Ubuntu  sudo apt install openssh-client
  Fedora/RHEL    sudo dnf install openssh-clients
  Arch           sudo pacman -S openssh" ;;
    esac
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/sc26-install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

# 2. The tutorial files: GitHub serves any branch or tag as a public tarball.
say "Downloading the tutorial ($repo, $ref)..."
fetch "https://codeload.github.com/$repo/tar.gz/refs/$ref" "$tmp/course.tar.gz" ||
    die "could not download https://codeload.github.com/$repo/tar.gz/refs/$ref"
mkdir "$tmp/unpack"
tar -xzf "$tmp/course.tar.gz" -C "$tmp/unpack"
src=
for dir in "$tmp"/unpack/*/"$subdir"; do
    [ -f "$dir/host/app.py" ] && src=$dir
done
[ -n "$src" ] || die "the download has no $subdir/host/app.py"

# Copy over any earlier install: new files replace old ones, and files you
# added (results/, notes) stay. Keep an edited exercise file.
mkdir -p "$home"
keep=
[ -f "$home/exercise/my_cholesky.jl" ] && keep="--exclude=./exercise/my_cholesky.jl"
(cd "$src" && tar -cf - $keep .) | (cd "$home" && tar -xf -)
say "Tutorial files are in $home"

# 3. Python 3.9+: use one that is already there, else a private one from uv.
python_ok() { "$1" -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; }
find_python() {
    for name in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
        path=$(command -v "$name" 2>/dev/null) || continue
        # On macOS without the Command Line Tools, /usr/bin/python3 only opens
        # an installer window; do not trigger it.
        if [ "$path" = /usr/bin/python3 ] && [ "$(uname)" = Darwin ] &&
                ! xcode-select -p >/dev/null 2>&1; then
            continue
        fi
        python_ok "$path" && { say "$path"; return 0; }
    done
    return 1
}
if ! python=$(find_python); then
    uv=$tools/uv
    if [ ! -x "$uv" ]; then
        say "No Python 3.9 or newer found; fetching uv to download a private Python..."
        fetch https://astral.sh/uv/install.sh "$tmp/uv-install.sh"
        # Into $home/.tools only: no shell-profile edits, no update receipt.
        UV_UNMANAGED_INSTALL=$tools sh "$tmp/uv-install.sh" --quiet ||
            die "could not install uv"
    fi
    # Keep uv's Python, its shortcuts and its cache in $home/.tools as well.
    export UV_PYTHON_INSTALL_DIR=$tools/python UV_PYTHON_BIN_DIR=$tools/bin UV_CACHE_DIR=$tools/cache
    "$uv" python install --quiet 3.12 || die "uv could not download Python 3.12"
    python=$("$uv" python find 3.12) || die "uv installed Python 3.12 but cannot find it"
fi
say "Using Python: $python"

# 4. Start the console. Under `curl ... | sh` this script reads from the pipe,
#    so give the console the terminal for its username and Odo prompts.
rm -rf "$tmp"
trap - EXIT INT TERM
cd "$home"
if [ -t 0 ]; then
    exec "$python" host/app.py "$@"
elif (: </dev/tty) 2>/dev/null; then
    exec "$python" host/app.py "$@" </dev/tty
else
    exec "$python" host/app.py "$@"
fi
