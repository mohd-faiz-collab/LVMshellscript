#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit
fi

echo "Updating package lists..."
apt-get update -y || yum update -y

echo "Installing LVM tools..."
apt-get install -y lvm2 || yum install -y lvm2

PV="/dev/xvdv"    # Single EBS volume (change this based on your environment)
VG_NAME="my_vg"   # Volume Group name
LV_NAME="my_lv"   # Logical Volume name
LV_SIZE="2800M"   # Size of the Logical Volume (2800M)
MOUNT_DIR="/mnt/my_lvm"  # Mount point

echo "Forcefully initializing Physical Volume on $PV..."
pvcreate -ff $PV

PV_SIZE=$(lsblk -bno SIZE $PV)

# Ensure the size is at least 3G (3 * 1024 * 1024 * 1024 = 3221225472 bytes)
if [ "$PV_SIZE" -lt 3221225472 ]; then
  echo "Error: The size of $PV is less than 3G."
  exit 1
fi

echo "Creating Volume Group $VG_NAME..."
vgcreate $VG_NAME $PV

echo "Creating Logical Volume $LV_NAME with size $LV_SIZE..."
lvcreate -L $LV_SIZE -n $LV_NAME $VG_NAME

echo "Formatting Logical Volume with ext4..."
mkfs.ext4 /dev/$VG_NAME/$LV_NAME

echo "Creating mount point at $MOUNT_DIR..."
mkdir -p $MOUNT_DIR

echo "Mounting the Logical Volume..."
mount /dev/$VG_NAME/$LV_NAME $MOUNT_DIR

UUID=$(blkid -s UUID -o value /dev/$VG_NAME/$LV_NAME)

echo "Adding the Logical Volume to /etc/fstab for permanent mounting..."
echo "UUID=$UUID $MOUNT_DIR ext4 defaults 0 0" >> /etc/fstab

echo "Reloading systemd to apply fstab changes..."
systemctl daemon-reload

echo "Mounting the Logical Volume..."
mount -a

echo "Currently mounted volumes:"
df -h

echo "LVM setup and permanent mounting is complete. Logical volume is mounted at $MOUNT_DIR."