#!/bin/bash
set -e

NVIDIA="$(lspci | grep -i 'nvidia')"

if [[ -z $NVIDIA ]]; then
  echo "No NVIDIA GPU found. Skipping."
  exit 0
fi

# CachyOS path: keep chwd-based setup used by this fork.
if pacman -Q linux-cachyos >/dev/null 2>&1; then
  GPU_ID=$(lspci -nn -d 10de: | grep -E "VGA|3D" | head -n1 | grep -oP '(?<=\[10de:)[0-9a-fA-F]{4}(?=\])')

  if [[ -z $GPU_ID ]]; then
    echo "No NVIDIA GPU ID found. Skipping."
    exit 0
  fi

  echo "[*] Found NVIDIA ID: $GPU_ID"
  echo "[*] Removing conflicting open-driver packages..."
  sudo pacman -Rdd --noconfirm libxnvctrl linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open nvidia-open-dkms 2>/dev/null || true

  if ! grep -q "$GPU_ID" /var/lib/chwd/ids/nvidia-580.ids; then
    echo "[*] Patching chwd ID list..."
    if [ -n "$(tail -c1 /var/lib/chwd/ids/nvidia-580.ids)" ]; then
      sudo sh -c "echo >> /var/lib/chwd/ids/nvidia-580.ids"
    fi
    sudo sed -i "\$a $GPU_ID" /var/lib/chwd/ids/nvidia-580.ids
  else
    echo "[*] GPU ID already present in 580 list."
  fi

  echo "[*] Removing old chwd profile..."
  sudo chwd -r nvidia-open-dkms --noconfirm || true

  echo "[*] Installing 580xx proprietary profile..."
  sudo chwd -a

  sudo pacman -S --needed --noconfirm libva-utils

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
