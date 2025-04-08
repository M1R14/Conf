#!/bin/bash

# Step 1: Check if 50unattended-upgrades exists in the current directory
if [[ -f "./50unattended-upgrades" ]]; then
    echo "Copying 50unattended-upgrades to /etc/apt/apt.conf.d/..."
    if ! sudo cp ./50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades; then
        echo "Error copying the file. Aborting."
        exit 1
    fi
else
    echo "50unattended-upgrades not found. Aborting."
    exit 1
fi

# Step 2: Install unattended-upgrades if not installed
if ! dpkg -l | grep -q unattended-upgrades; then
    read -p "Unattended-upgrades not installed. Install it? (y/n): " install_choice
    install_choice=$(echo "$install_choice" | tr '[:upper:]' '[:lower:]' | xargs)  # Normalize input to lowercase and trim whitespace
    
    if [[ "$install_choice" == "y" ]]; then
        echo "Running apt-get update..."
        if ! sudo apt-get update; then
            echo "Error: apt-get update failed. Aborting."
            exit 1
        fi

        echo "Installing unattended-upgrades..."
        if ! sudo apt-get install unattended-upgrades -y; then
            echo "Error installing unattended-upgrades. Aborting."
            exit 1
        fi
    else
        echo "Unattended-upgrades not installed. Aborting."
        exit 1
    fi
fi

# Step 3: Set the update time
while true; do
    read -p "What time should automatic updates run? (HH:MM, e.g., 01:00, press Enter for default 01:00): " update_time
    update_time=${update_time:-"01:00"}  # Default to 01:00 if no input

    # Validate time format (HH:MM)
    if [[ "$update_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
        break
    else
        echo "Invalid format. Please enter time in HH:MM format."
    fi
done

# Extract hours and minutes, ensuring two digits
update_hour=${update_time:0:2}
update_minute=${update_time:3:2}
update_hour=$(printf "%02d" $update_hour)
update_minute=$(printf "%02d" $update_minute)

# Configure apt-daily.timer
sudo mkdir -p /etc/systemd/system/apt-daily.timer.d
echo "[Timer]
OnCalendar=
OnCalendar=*-*-* $update_hour:$update_minute
RandomizedDelaySec=0" | sudo tee /etc/systemd/system/apt-daily.timer.d/override.conf

# Configure apt-daily-upgrade.timer (10 minutes after update)
upgrade_hour=$((update_hour))
upgrade_minute=$((update_minute + 10))
if [[ $upgrade_minute -ge 60 ]]; then
    upgrade_minute=$((upgrade_minute - 60))
    upgrade_hour=$((upgrade_hour + 1))
fi

# Ensure time is always two digits
upgrade_hour=$(printf "%02d" $upgrade_hour)
upgrade_minute=$(printf "%02d" $upgrade_minute)

sudo mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d
echo "[Timer]
OnCalendar=
OnCalendar=*-*-* $upgrade_hour:$upgrade_minute
RandomizedDelaySec=0" | sudo tee /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf

# Step 4: Reload systemd and restart the timers
sudo systemctl daemon-reload
if ! sudo systemctl restart apt-daily.timer || ! sudo systemctl restart apt-daily-upgrade.timer; then
    echo "Error restarting the timers. Aborting."
    exit 1
fi

# Step 5: Check if NetBird is present in the config, then check if it is installed
if ! grep -q "origin=pkgs.netbird.io,codename=stable,label=Artifactory" /etc/apt/apt.conf.d/50unattended-upgrades; then
    if dpkg -l | grep -q netbird; then
        # Add NetBird origin to 50unattended-upgrades if not already present
        echo "NetBird is installed – adding APT origin to 50unattended-upgrades..."
        if ! sudo sed -i '/Unattended-Upgrade::Origins-Pattern {/a \ \ \ \ "origin=pkgs.netbird.io,codename=stable,label=Artifactory";' /etc/apt/apt.conf.d/50unattended-upgrades; then
            echo "Error adding NetBird APT origin. Aborting."
            exit 1
        fi
        echo "NetBird APT origin added successfully."
    else
        echo "NetBird not installed. Skipping APT origin addition."
    fi
fi

# Add NetBird entry to Allowed-Origins-Pattern if not already present
if ! grep -q "origin=pkgs.netbird.io,codename=stable,label=Artifactory" /etc/apt/apt.conf.d/50unattended-upgrades; then
    echo "Adding NetBird to Allowed-Origins-Pattern..."
    if ! sudo sed -i '/Unattended-Upgrade::Allowed-Origins-Pattern {/a \ \ \ \ "origin=pkgs.netbird.io,codename=stable,label=Artifactory";' /etc/apt/apt.conf.d/50unattended-upgrades; then
        echo "Error adding NetBird to Allowed-Origins-Pattern. Aborting."
        exit 1
    fi
    echo "NetBird added to Allowed-Origins-Pattern."
else
    echo "NetBird already present in Allowed-Origins-Pattern."
fi

