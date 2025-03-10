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
pacstrap /mnt base linux linux-firmware nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the system
arch-chroot /mnt /bin/bash <<EOF
  # Timezone
  ln -sf /usr/share/zoneinfo/Israel /etc/localtime
  hwclock --systohc

  # Locale
  sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf

  # Initramfs
  mkinitcpio -P

  # Install additional packages
  pacman -S --noconfirm grub base-devel efibootmgr os-prober mtools dosfstools linux-headers networkmanager nm-connection-editor pulseaudio pavucontrol dialog

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

  # Uncomment wheel group in sudoers
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  # Set passwords non-interactively to '1'
  echo "main:1" | chpasswd
  echo "root:1" | chpasswd

  # Install display driver (placeholder, adjust as needed)
  pacman -S --noconfirm xf86-video-vmware  # You mentioned this might be it; replace if incorrect

  # Install Xorg and desktop environment
  pacman -S --noconfirm xorg
  pacman -S --noconfirm lightdm lightdm-gtk-greeter
  sed -i 's/#greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
  systemctl enable lightdm
  pacman -S --noconfirm xfce4 xfce4-goodies
EOF

# Unmount and reboot
umount -a
reboot