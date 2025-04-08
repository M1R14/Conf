#!/bin/bash

# Check if the system is Debian
if ! grep -iq "debian" /etc/os-release; then
    echo "This is not a Debian system. Exiting the script."
    exit 0
fi

# Update package list and install required packages
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Add NetBird GPG key
curl -sSL https://pkgs.netbird.io/debian/public.key | sudo gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg

# Add the NetBird repository
echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' | sudo tee /etc/apt/sources.list.d/netbird.list

# Update APT's cache
sudo apt-get update

# Install NetBird CLI or GUI package
# Uncomment the desired line below
# sudo apt-get install -y netbird-ui   # for GUI package
sudo apt-get install -y netbird   # for CLI only
