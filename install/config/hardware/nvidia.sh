#!/bin/bash
set -e

NVIDIA="$(lspci | grep -i 'nvidia')"

if [[ -z $NVIDIA ]]; then
  echo "No NVIDIA GPU found. Skipping."
  exit 0
fi

if echo "$NVIDIA" | grep -qE "GTX 16[0-9]{2}|RTX [2-5][0-9]{3}|RTX PRO [0-9]{4}|Quadro RTX|RTX A[0-9]{4}|A[1-9][0-9]{2}|H[1-9][0-9]{2}|T4|L[0-9]+"; then
  PACKAGES=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver)
  GPU_ARCH="turing_plus"
elif echo "$NVIDIA" | grep -qE "GTX (9[0-9]{2}|10[0-9]{2})|GT 10[0-9]{2}|Quadro [PM][0-9]{3,4}|Quadro GV100|MX *[0-9]+|Titan (X|Xp|V)|Tesla V100"; then
  PACKAGES=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils)
  GPU_ARCH="maxwell_pascal_volta"
fi

if [[ -z ${PACKAGES+x} ]]; then
  echo "No compatible driver for your NVIDIA GPU. See: https://wiki.archlinux.org/title/NVIDIA"
  exit 0
fi

# CachyOS path: prefer kernel-bound modules for Turing+, keep 580xx DKMS for legacy.
if pacman -Q linux-cachyos >/dev/null 2>&1 || pacman -Q linux-cachyos-lts >/dev/null 2>&1; then
  CONFLICTING_PACKAGES=()

  if [[ $GPU_ARCH == "turing_plus" ]]; then
    echo "[*] Detected Turing+ NVIDIA GPU on CachyOS. Using kernel-bound nvidia-open modules."

    for pkg in nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-dkms nvidia-open-dkms linux-cachyos-nvidia linux-cachyos-lts-nvidia; do
      if pacman -Q "$pkg" >/dev/null 2>&1; then
        CONFLICTING_PACKAGES+=("$pkg")
      fi
    done

    PREBUILT_MODULES=()
    if pacman -Q linux-cachyos >/dev/null 2>&1; then
      PREBUILT_MODULES+=(linux-cachyos-nvidia-open)
    fi
    if pacman -Q linux-cachyos-lts >/dev/null 2>&1; then
      PREBUILT_MODULES+=(linux-cachyos-lts-nvidia-open)
    fi

  elif [[ $GPU_ARCH == "maxwell_pascal_volta" ]]; then
    echo "[*] Detected Maxwell/Pascal/Volta NVIDIA GPU on CachyOS. Using 580xx DKMS."

    for pkg in linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open nvidia-open-dkms linux-cachyos-nvidia linux-cachyos-lts-nvidia; do
      if pacman -Q "$pkg" >/dev/null 2>&1; then
        CONFLICTING_PACKAGES+=("$pkg")
      fi
    done

    HEADER_PACKAGES=()
    if pacman -Q linux-cachyos >/dev/null 2>&1 && ! pacman -Q linux-cachyos-headers >/dev/null 2>&1; then
      HEADER_PACKAGES+=(linux-cachyos-headers)
    fi
    if pacman -Q linux-cachyos-lts >/dev/null 2>&1 && ! pacman -Q linux-cachyos-lts-headers >/dev/null 2>&1; then
      HEADER_PACKAGES+=(linux-cachyos-lts-headers)
    fi

    if (( ${#HEADER_PACKAGES[@]} > 0 )); then
      omarchy-pkg-add "${HEADER_PACKAGES[@]}"
    fi

  fi

  if (( ${#CONFLICTING_PACKAGES[@]} > 0 )); then
    sudo pacman -Rdd --noconfirm "${CONFLICTING_PACKAGES[@]}"
  fi

  if [[ $GPU_ARCH == "turing_plus" ]]; then
    omarchy-pkg-add "${PREBUILT_MODULES[@]}" nvidia-utils lib32-nvidia-utils libva-nvidia-driver
  elif [[ $GPU_ARCH == "maxwell_pascal_volta" ]]; then
    omarchy-pkg-add nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils
  fi

  omarchy-pkg-add libva-utils

  cat >>"$HOME/.config/uwsm/env" <<'EOF'

# NVIDIA
export LIBVA_DRIVER_NAME=nvidia
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export NVD_BACKEND=direct
export MOZ_DISABLE_RDD_SANDBOX=1
export CUDA_DISABLE_PERF_BOOST=1
EOF

  exit 0
fi

# Upstream Arch path.
KERNEL_HEADERS="$(pacman -Qqs '^linux(-zen|-lts|-hardened)?$' | head -1)-headers"
omarchy-pkg-add "$KERNEL_HEADERS" "${PACKAGES[@]}"

sudo tee /etc/modprobe.d/nvidia.conf <<EOF >/dev/null
options nvidia_drm modeset=1
EOF

sudo tee /etc/mkinitcpio.conf.d/nvidia.conf <<EOF >/dev/null
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

if [[ $GPU_ARCH = "turing_plus" ]]; then
  cat >>"$HOME/.config/hypr/envs.conf" <<'EOF'

# NVIDIA (Turing+ with GSP firmware)
env = NVD_BACKEND,direct
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF
elif [[ $GPU_ARCH = "maxwell_pascal_volta" ]]; then
  cat >>"$HOME/.config/hypr/envs.conf" <<'EOF'

# NVIDIA (Maxwell/Pascal/Volta without GSP firmware)
env = NVD_BACKEND,egl
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF
fi
