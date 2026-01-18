#!/usr/bin/env bash
set -euo pipefail

# Detect sudo usage
SUDO=""
if [ "$EUID" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "This script needs root privileges to install packages. Please run as root or install sudo."
    exit 1
  fi
fi

# Read OS info
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Cannot detect OS: /etc/os-release not readable."
  exit 1
fi

os_id="${ID,,}"           # lowercase ID
os_like="${ID_LIKE:-}" 
os_like="${os_like,,}"    # lowercase ID_LIKE

echo "Detected OS: ${NAME:-Unknown} (ID=${ID:-unknown}, ID_LIKE=${ID_LIKE:-none})"

# Package lists
OPENSUSE_PKGS=(
  libqt5-qtbase-devel
  libqt5-qtmultimedia-devel
  libqt5-qtdeclarative-devel
  libqt5-qtquickcontrols2
  libexiv2-devel
  cmake
  gcc-c++
)
DEBIAN_PKGS=(
  qtbase5-dev
  qtmultimedia5-dev
  qtdeclarative5-dev
  qml-module-qtquick2
  qml-module-qtquick-controls2
  qml-module-qtquick-layouts
  qml-module-qtquick-window2
  libexiv2-dev
  cmake
  build-essential
)

install_opensuse() {
  echo "Selected installer: zypper (openSUSE)"
  if ! command -v zypper >/dev/null 2>&1; then
    echo "zypper not found. Cannot install on this system."
    exit 1
  fi

  echo "The following packages will be installed for openSUSE:"
  printf '  %s\n' "${OPENSUSE_PKGS[@]}"

  echo "Installing build dependencies for openSUSE..."
  ${SUDO} zypper --non-interactive install "${OPENSUSE_PKGS[@]}"
  echo "openSUSE packages installed (or already present)."
}

install_debian() {
  echo "Selected installer: apt (Debian/Ubuntu)"
  # prefer apt, fall back to apt-get if necessary
  if command -v apt >/dev/null 2>&1; then
    APT_CMD="apt"
  elif command -v apt-get >/dev/null 2>&1; then
    APT_CMD="apt-get"
  else
    echo "apt/apt-get not found. Cannot install on this system."
    exit 1
  fi

  echo "The following packages will be installed for Debian/Ubuntu:"
  printf '  %s\n' "${DEBIAN_PKGS[@]}"

  echo "Updating package lists..."
  ${SUDO} ${APT_CMD} update

  echo "Installing build dependencies for Debian/Ubuntu..."
  # apt supports -y; apt-get uses -y as well
  ${SUDO} ${APT_CMD} install -y "${DEBIAN_PKGS[@]}"
  echo "Debian/Ubuntu packages installed (or already present)."
}

# Decide which installer to run
if [[ "$os_id" == opensuse* || "$os_like" == *suse* || "$os_like" == *opensuse* ]]; then
  install_opensuse
elif [[ "$os_id" == debian || "$os_id" == ubuntu || "$os_like" == *debian* ]]; then
  install_debian
else
  echo "Unsupported or unrecognized distribution: ID='${ID}' ID_LIKE='${ID_LIKE:-}'"
  echo "This script currently supports openSUSE (zypper) and Debian/Ubuntu (apt)."
  exit 2
fi

echo "Done."