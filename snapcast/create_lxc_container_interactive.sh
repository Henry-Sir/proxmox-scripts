#!/bin/bash

# Function to display input box and get user input
get_input() {
  local message=$1
  local default_value=$2
  whiptail --inputbox "$message" 8 78 "$default_value" --title "Create LXC container" 3>&1 1>&2 2>&3
}
get_yesno() {
  local message=$1
  whiptail "$message" 8 78 --yesno --title "Create LXC container" 3>&1 1>&2 2>&3
}

# Variables with default values
HOSTNAME=$(get_input "Enter container hostname:" "snapcast")
TEMPLATE=$(get_input "Enter container template:" "local-nvme:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst")
STORAGE=$(get_input "Enter storage location:" "local-lvm")
MEMORY=$(get_input "Enter memory (MB):" "1024")
SWAP=$(get_input "Enter swap (MB):" "512")
DISK_SIZE=$(get_input "Enter disk size (e.g., 8G):" "8G")
NET_IFACE=$(get_input "Enter network interface (e.g., vmbr0):" "vmbr0")
IP_ADDR=$(get_input "Enter IP address (e.g., 192.168.1.100/24):" "192.168.5.247/24")
GATEWAY=$(get_input "Enter gateway IP address:" "192.168.5.254")


# Create LXC container
CREAT_MSG="Hostname: $HOSTNAME
Template: $TEMPLATE
Storage: $STORAGE
Memory: $MEMORY MB
Swap: $SWAP MB
Disk size: $DISK_SIZE
Network interface: $NET_IFACE
IP address: $IP_ADDR
Gateway: $GATEWAY" 


if (whiptail --title "Creating LXC container with the following configuration:" --yesno "$CREAT_MSG" 20 78); then
  echo "Creating LXC container with the following configuration:"
  echo "$CREAT_MSG"
  echo ""
  CTID=$(pct create "$(pvesh get /cluster/nextid -output-format=json-pretty)" -hostname "$HOSTNAME" -ostemplate "$TEMPLATE" -storage "$STORAGE" -memory "$MEMORY" -swap "$SWAP" -net0 "name=eth0,bridge=$NET_IFACE,ip=$IP_ADDR,gw=$GATEWAY" -rootfs "$STORAGE:$DISK_SIZE" -onboot 1 -start 1 -unprivileged 1 -features "nesting=1" -force 1)
  echo "LXC container created with ID $CTID."
  echo ""

  # Disable IPv6
   if (whiptail --title "Disable IPv6" --yesno "Do you want to disable IPv6?\nReboot needed." 8 78); then
    pct exec "$CTID" -- sh -c "echo 'net.ipv6.conf.all.disable_ipv6 = 1' > /etc/sysctl.conf"
    pct exec "$CTID" -- sh -c "echo 'net.ipv6.conf.default.disable_ipv6 = 1' > /etc/sysctl.conf"
    pct exec "$CTID" -- sh -c "echo 'net.ipv6.conf.lo.disable_ipv6 = 1' > /etc/sysctl.conf"
    pct exec "$CTID" -- sh -c "echo 'net.ipv6.conf.tun0.disable_ipv6 = 1' > /etc/sysctl.conf"
    echo "IPv6 disabled."
    echo "Reboot after installtion needed."
   fi


  # Ask for permission before proceeding to the second script
  if (whiptail --title "Install Snapcast Server" --yesno "Do you want to install Snapcast Server in the newly created container?" 8 78); then
    echo "Installing Snapcast Server..."
    wget https://raw.githubusercontent.com/Henry-Sir/proxmox-scripts/main/snapcast/create_lxc_container_interactive.sh
    ./install_snapcast_server.sh "$CTID"
  else
    echo "Snapcast Server installation skipped."
  fi

fi

