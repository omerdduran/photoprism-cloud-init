#!/bin/bash

# Helper script to prepare an SD card with cloud-init configuration for PhotoPrism

# Exit on error
set -e

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Function to display help
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -d, --device DEVICE   SD card device (e.g., /dev/sdb, /dev/mmcblk0)"
  echo "  -i, --image IMAGE     Path to Ubuntu image file (if already downloaded)"
  echo "  -h, --help            Show this help message"
  echo ""
  echo "Example:"
  echo "  sudo $0 -d /dev/sdb"
  exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -d|--device)
      SD_DEVICE="$2"
      shift
      shift
      ;;
    -i|--image)
      IMAGE_PATH="$2"
      shift
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# Check required parameters
if [ -z "$SD_DEVICE" ]; then
  echo "Error: SD card device is required"
  show_help
fi

# Confirm the device
echo "WARNING: This will erase all data on $SD_DEVICE"
echo "Are you sure you want to continue? (y/n)"
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 1
fi

# Set variables
TEMP_DIR=$(mktemp -d)
UBUNTU_IMAGE_URL="https://cdimage.ubuntu.com/releases/24.04.2/release/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img.xz"
CLOUD_INIT_DIR="$(dirname "$(readlink -f "$0")")/../cloud-init"
DOCKER_DIR="$(dirname "$(readlink -f "$0")")/../docker"
TRAEFIK_DIR="$(dirname "$(readlink -f "$0")")/../traefik"

echo "=== PhotoPrism Cloud-Init SD Card Preparation Tool ==="
echo "SD Device: $SD_DEVICE"
echo "Temp Dir: $TEMP_DIR"
echo "Cloud-Init Dir: $CLOUD_INIT_DIR"
echo "Docker Dir: $DOCKER_DIR"
echo "Traefik Dir: $TRAEFIK_DIR"

# Download Ubuntu image if not provided
if [ -z "$IMAGE_PATH" ]; then
  echo "Downloading Ubuntu 24.04 image..."
  wget -O "$TEMP_DIR/ubuntu.img.xz" "$UBUNTU_IMAGE_URL"
  IMAGE_PATH="$TEMP_DIR/ubuntu.img.xz"
fi

# Extract image if it's compressed
if [[ "$IMAGE_PATH" == *.xz ]]; then
  echo "Extracting image..."
  xz -d -v "$IMAGE_PATH" -c > "$TEMP_DIR/ubuntu.img"
  IMAGE_PATH="$TEMP_DIR/ubuntu.img"
elif [[ "$IMAGE_PATH" == *.zip ]]; then
  echo "Extracting image..."
  unzip "$IMAGE_PATH" -d "$TEMP_DIR"
  IMAGE_PATH=$(find "$TEMP_DIR" -name "*.img" | head -n 1)
fi

# Flash image to SD card
echo "Flashing image to $SD_DEVICE..."
dd if="$IMAGE_PATH" of="$SD_DEVICE" bs=4M status=progress conv=fsync

# Wait for the OS to detect the newly written partitions
echo "Waiting for partitions to be detected..."
sleep 5
sync

# Find the boot partition
BOOT_PARTITION=""
if [[ "$SD_DEVICE" == *"mmcblk"* ]]; then
  BOOT_PARTITION="${SD_DEVICE}p1"
else
  BOOT_PARTITION="${SD_DEVICE}1"
fi

# Mount the boot partition
echo "Mounting boot partition..."
MOUNT_POINT="$TEMP_DIR/boot"
mkdir -p "$MOUNT_POINT"
mount "$BOOT_PARTITION" "$MOUNT_POINT"

# Create a directory for docker compose file
echo "Creating docker directory on SD card..."
mkdir -p "$MOUNT_POINT/docker"

# Create a directory for traefik config files
echo "Creating traefik directory on SD card..."
mkdir -p "$MOUNT_POINT/traefik/conf.d"
mkdir -p "$MOUNT_POINT/traefik/certs"

# Copy traefik config files
echo "Copying traefik configuration files..."
cp "$TRAEFIK_DIR/traefik.yaml" "$MOUNT_POINT/traefik/"
cp "$TRAEFIK_DIR/conf.d/dynamic_conf.yaml" "$MOUNT_POINT/traefik/conf.d/"
cp "$TRAEFIK_DIR/generate-certs.sh" "$MOUNT_POINT/traefik/"
chmod +x "$MOUNT_POINT/traefik/generate-certs.sh"

# Create necessary directories
echo "Creating required directories..."
mkdir -p "$MOUNT_POINT/docker"

# Copy docker compose file
echo "Copying docker compose file..."
cp "$DOCKER_DIR/compose.yaml" "$MOUNT_POINT/docker/"

# Copy cloud-init files
echo "Copying cloud-init files..."
cp "$CLOUD_INIT_DIR/user-data" "$MOUNT_POINT/"
cp "$CLOUD_INIT_DIR/meta-data" "$MOUNT_POINT/"
cp "$CLOUD_INIT_DIR/network-config" "$MOUNT_POINT/"

# Set proper permissions
echo "Setting proper permissions..."
chmod 600 "$MOUNT_POINT/user-data"
chmod 600 "$MOUNT_POINT/meta-data"
chmod 600 "$MOUNT_POINT/network-config"

# Sync and unmount
echo "Syncing and unmounting..."
sync
umount "$MOUNT_POINT"

# Clean up
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo "Done! Your SD card is ready."
echo "Insert it into your Raspberry Pi and connect it to Ethernet."
echo "PhotoPrism will be available at https://photoprismpi.local after setup (10-15 minutes)."
echo "Default login: admin / photoprismpi" 