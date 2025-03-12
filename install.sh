#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Starting Arch Linux installation..."

# Set NTP
timedatectl set-ntp true

# Partitioning /dev/sda
echo "Partitioning /dev/sda..."
echo -e "g\nn\n\n\n+1G\nn\n\n\n\nw" | fdisk /dev/sda

# Format partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

# Mount partitions
mount /dev/sda2 /mnt

# Install base system
pacstrap /mnt base linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the system
arch-chroot /mnt /bin/bash <<EOF
  # Timezone
  ln -sf /usr/share/zoneinfo/Israel /etc/localtime
  hwclock --systohc

  # Locale - Enable both en_US.UTF-8 and he_IL.UTF-8
  sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
  sed -i 's/#he_IL.UTF-8/he_IL.UTF-8/' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf

  # Initramfs
  mkinitcpio -P

  # Install additional packages
  pacman -S --noconfirm grub base-devel efibootmgr os-prober mtools dosfstools linux-headers networkmanager nm-connection-editor pipewire pipewire-pulse pipewire-alsa pavucontrol dialog

  # Mount EFI partition
  mkdir /boot/EFI
  mount /dev/sda1 /boot/EFI

  # GRUB setup
  grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
  grub-mkconfig -o /boot/grub/grub.cfg

  # Enable NetworkManager
  systemctl enable NetworkManager

  # Create user 'main'
  useradd -m -G wheel main
  passwd -d main  # Remove password for 'main'

  # Uncomment wheel group in sudoers with NOPASSWD (optional)
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

  # Set root password (keep it for safety)
  echo "root:1" | chpasswd

  # Install display driver (adjust as needed)
  pacman -S --noconfirm xf86-video-vmware

  # Install Xorg and desktop environment
  pacman -S --noconfirm xorg sddm plasma konsole nano gedit dolphin firefox
  pacman -R --noconfirm plasma-welcome discover
  systemctl enable sddm

  # Configure SDDM autologin
  mkdir -p /etc/sddm.conf.d
  cat << 'SDDM' > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=main
Session=plasma.desktop
SDDM

  # Set keyboard layout for console
  echo "KEYMAP=us" > /etc/vconsole.conf
  echo "FONT=lat2-16" >> /etc/vconsole.conf

  # Set X11 keyboard layout
  cat << 'KEYBOARD' > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,il"
    Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
KEYBOARD

  # Create .config directory for user 'main' and download config files
  mkdir -p /home/main/.config
  curl -o /home/main/.config/plasma-org.kde.plasma.desktop-appletsrc https://raw.githubusercontent.com/DevByte1328/arch-install/refs/heads/master/plasma-org.kde.plasma.desktop-appletsrc
  curl -o /home/main/.config/plasmashellrc https://raw.githubusercontent.com/DevByte1328/arch-install/refs/heads/master/plasmashellrc
  chown -R main:main /home/main/.config
EOF

# Unmount and reboot
umount -a
reboot