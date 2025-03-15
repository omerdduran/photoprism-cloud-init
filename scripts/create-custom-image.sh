#!/bin/bash

set -e

# Configuration
UBUNTU_VERSION="24.04.2"
UBUNTU_IMAGE_URL="https://cdimage.ubuntu.com/releases/${UBUNTU_VERSION}/release/ubuntu-${UBUNTU_VERSION}-preinstalled-server-arm64+raspi.img.xz"
BUILD_DIR="${1:-cloud-init}"
BUILD_ID="${2:-$(date +%Y%m%d%H%M%S)}"
IMAGE_NAME="ubuntu-${UBUNTU_VERSION}-photoprism-raspi-${BUILD_ID}.img"
MOUNT_POINT="/tmp/ubuntu-mount"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 
    exit 1
fi

# Create working directory
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

echo "=== Downloading Ubuntu Server image ==="
wget -O ubuntu.img.xz "$UBUNTU_IMAGE_URL"

echo "=== Extracting image ==="
xz -d ubuntu.img.xz

echo "=== Creating a copy of the image ==="
cp ubuntu.img "$IMAGE_NAME"

# Get the start sector of the boot partition
SECTOR_SIZE=512
BOOT_OFFSET=$(fdisk -l "$IMAGE_NAME" | grep "FAT32" | awk '{print $2}')
BOOT_OFFSET_BYTES=$((BOOT_OFFSET * SECTOR_SIZE))

echo "=== Mounting boot partition ==="
mkdir -p "$MOUNT_POINT"
mount -o loop,offset=$BOOT_OFFSET_BYTES "$IMAGE_NAME" "$MOUNT_POINT"

echo "=== Copying cloud-init files ==="
cp -v "${BUILD_DIR}/user-data" "$MOUNT_POINT/user-data"
[ -f "${BUILD_DIR}/meta-data" ] && cp -v "${BUILD_DIR}/meta-data" "$MOUNT_POINT/meta-data"
[ -f "${BUILD_DIR}/network-config" ] && cp -v "${BUILD_DIR}/network-config" "$MOUNT_POINT/network-config"

echo "=== Unmounting boot partition ==="
umount "$MOUNT_POINT"

echo "=== Compressing final image ==="
xz -z "$IMAGE_NAME"

echo "=== Moving image to output directory ==="
mkdir -p "$(dirname "$BUILD_DIR")/output"
mv "${IMAGE_NAME}.xz" "$(dirname "$BUILD_DIR")/output/"

echo "=== Cleaning up ==="
cd ..
rm -rf "$WORK_DIR"

echo "=== Custom image created: $(dirname "$BUILD_DIR")/output/${IMAGE_NAME}.xz ==="
echo "Users can flash this image directly to their SD card using Raspberry Pi Imager or dd." 