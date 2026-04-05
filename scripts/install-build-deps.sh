#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

prepare_apt_sources() {
  local ubuntu_sources="/etc/apt/sources.list.d/ubuntu.sources"
  local arm64_sources="/etc/apt/sources.list.d/ubuntu-arm64.sources"
  local yarn_list="/etc/apt/sources.list.d/yarn.list"
  local codename

  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-noble}")"

  if [[ -f "$yarn_list" && ! -f "${yarn_list}.disabled-by-wine-build" ]]; then
    sudo mv "$yarn_list" "${yarn_list}.disabled-by-wine-build"
  fi

  if [[ -f "$ubuntu_sources" ]]; then
    sudo cp "$ubuntu_sources" "${ubuntu_sources}.bak-wine-build" 2>/dev/null || true
    sudo tee "$ubuntu_sources" >/dev/null <<EOF
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: ${codename} ${codename}-updates ${codename}-backports
Components: main universe restricted multiverse
Architectures: amd64 i386
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: ${codename}-security
Components: main universe restricted multiverse
Architectures: amd64 i386
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

    sudo tee "$arm64_sources" >/dev/null <<EOF
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: ${codename} ${codename}-updates ${codename}-backports ${codename}-security
Components: main universe restricted multiverse
Architectures: arm64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  fi
}

prepare_apt_sources
sudo dpkg --add-architecture i386
sudo dpkg --add-architecture arm64
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  autoconf \
  automake \
  bison \
  build-essential \
  ca-certificates \
  clang \
  curl \
  flex \
  g++-13-aarch64-linux-gnu \
  g++-mingw-w64-i686 \
  g++-mingw-w64-x86-64 \
  gcc-13-aarch64-linux-gnu \
  gcc-mingw-w64-i686 \
  gcc-mingw-w64-x86-64 \
  git \
  jq \
  lld \
  llvm \
  make \
  patchelf \
  pkg-config \
  python3 \
  rsync \
  tar \
  unzip \
  wget \
  xz-utils \
  zstd \
  libc6-dev-i386 \
  libasound2-dev \
  libasound2-dev:i386 \
  libasound2-dev:arm64 \
  libdbus-1-dev \
  libdbus-1-dev:i386 \
  libdbus-1-dev:arm64 \
  libfontconfig-dev \
  libfontconfig-dev:i386 \
  libfontconfig-dev:arm64 \
  libfreetype-dev \
  libfreetype-dev:i386 \
  libfreetype-dev:arm64 \
  libgl1-mesa-dev \
  libgl1-mesa-dev:i386 \
  libgl1-mesa-dev:arm64 \
  libgnutls28-dev \
  libgnutls28-dev:i386 \
  libgnutls28-dev:arm64 \
  libpulse-dev \
  libpulse-dev:i386 \
  libpulse-dev:arm64 \
  libsdl2-dev \
  libsdl2-dev:i386 \
  libsdl2-dev:arm64 \
  libudev-dev \
  libudev-dev:i386 \
  libudev-dev:arm64 \
  libusb-1.0-0-dev \
  libusb-1.0-0-dev:i386 \
  libusb-1.0-0-dev:arm64 \
  libvulkan-dev \
  libvulkan-dev:i386 \
  libvulkan-dev:arm64 \
  libwayland-dev \
  libwayland-dev:i386 \
  libwayland-dev:arm64 \
  libx11-dev \
  libx11-dev:i386 \
  libx11-dev:arm64 \
  libxcomposite-dev \
  libxcomposite-dev:i386 \
  libxcomposite-dev:arm64 \
  libxcursor-dev \
  libxcursor-dev:i386 \
  libxcursor-dev:arm64 \
  libxext-dev \
  libxext-dev:i386 \
  libxext-dev:arm64 \
  libxi-dev \
  libxi-dev:i386 \
  libxi-dev:arm64 \
  libxinerama-dev \
  libxinerama-dev:i386 \
  libxinerama-dev:arm64 \
  libxrandr-dev \
  libxrandr-dev:i386 \
  libxrandr-dev:arm64 \
  libxrender-dev \
  libxrender-dev:i386 \
  libxrender-dev:arm64 \
  libxxf86vm-dev \
  libxxf86vm-dev:i386 \
  libxxf86vm-dev:arm64 \
  ocl-icd-opencl-dev \
  ocl-icd-opencl-dev:i386 \
  ocl-icd-opencl-dev:arm64

echo "Build dependencies installed."
