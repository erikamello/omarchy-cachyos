echo "Migrate legacy mobile NVIDIA GPUs to nvidia-580xx driver (if needed)"

# Only migrate MX1xx, 2xx or 3xx (Pascal/Maxwell)
NVIDIA="$(lspci | grep -i 'nvidia')"
if echo "$NVIDIA" | grep -qE "MX1|MX2|MX3"; then
  if ! pacman -Qq | grep -qE '^linux(-[a-z0-9]+)*-headers$'; then
    echo "Error: no linux headers package installed (required for DKMS drivers). Please install the appropriate headers and re-run this migration."
    exit 1
  fi

  CONFLICTING_PACKAGES=()
  for pkg in linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open nvidia-open-dkms nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      CONFLICTING_PACKAGES+=("$pkg")
    fi
  done

  if (( ${#CONFLICTING_PACKAGES[@]} > 0 )); then
    sudo pacman -Rdd --noconfirm "${CONFLICTING_PACKAGES[@]}"
  fi

  sudo pacman -S --noconfirm --needed nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils

  # Verify packages were installed
  if ! pacman -Qq nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils &>/dev/null; then
    echo "Error: NVIDIA 580xx driver packages failed to install"
    exit 1
  fi
fi
