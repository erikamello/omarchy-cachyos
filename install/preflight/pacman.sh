echo "Remove known package conflicts before base package install"

# Legacy Omarchy Chromium package conflicts with community chromium.
for pkg in omarchy-chromium omarchy-chromium-bin; do
  if omarchy-pkg-present $pkg; then
    omarchy-pkg-drop $pkg
  fi
done

# CachyOS can ship tldr, but this fork installs tealdeer instead.
if omarchy-pkg-present tldr && omarchy-pkg-missing tealdeer; then
  omarchy-pkg-drop tldr
fi

if [[ -n ${OMARCHY_ONLINE_INSTALL:-} ]]; then
  # Install build tools
  omarchy-pkg-add base-devel

  # Configure pacman
  sudo cp -f $OMARCHY_PATH/default/pacman/pacman-${OMARCHY_MIRROR:-stable}.conf /etc/pacman.conf
  sudo cp -f $OMARCHY_PATH/default/pacman/mirrorlist-${OMARCHY_MIRROR:-stable} /etc/pacman.d/mirrorlist

  sudo pacman-key --recv-keys 40DFB630FF42BCFFB047046CF0134EE680CAC571 --keyserver keys.openpgp.org
  sudo pacman-key --lsign-key 40DFB630FF42BCFFB047046CF0134EE680CAC571

  sudo pacman -Sy
  omarchy-pkg-add omarchy-keyring

  # Refresh all repos
  sudo pacman -Syyuu --noconfirm
fi
