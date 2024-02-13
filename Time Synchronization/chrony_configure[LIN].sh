#!/bin/bash

# Installs and configures Chrony service on a linux server.
#
# Usage: ./script 'NTP_SERVER_IP1,NTP_SERVER_IP2,...'
# Script requires one or more IP addresses and or hostnames.
# 
# Copyright (C) 2024  Peter Zendzian <zendzipr@gmail.com>
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

install_and_configure_chrony() {
    local servers_string=$1
    echo "Chrony configuration file not found. Attempting to install Chrony..."

    # Determine the package manager and install Chrony
    if command -v apt-get >/dev/null; then
        echo "Using apt-get to install Chrony."
        sudo apt-get update
        sudo apt-get install -y chrony
    elif command -v yum >/dev/null; then
        echo "Using yum to install Chrony."
        sudo yum install -y chrony
    else
        echo "Neither apt-get nor yum is available. Unable to install Chrony."
        exit 1
    fi

    # Check if the Chrony configuration file exists after installation
    if [[ -f /etc/chrony/chrony.conf || -f /etc/chrony.conf ]]; then
        echo "Chrony installed successfully."
        # Call the configure function again after installation
        configure_chrony_with_servers "$servers_string"
    else
        echo "Failed to install Chrony or locate a configuration file after installation."
        exit 1
    fi
}

# Function to install Chrony
install_chrony() {
    echo "Checking for Chrony installation..."

    # Determine the package manager and install Chrony
    if command -v apt-get >/dev/null; then
        echo "Using apt-get to install Chrony."
        sudo apt-get update
        sudo apt-get install -y chrony
    elif command -v yum >/dev/null; then
        echo "Using yum to install Chrony."
        sudo yum install -y chrony
    else
        echo "Neither apt-get nor yum is available. Unable to install Chrony."
        exit 1
    fi

    # Check which Chrony service is available (chronyd or chrony)
    if systemctl list-unit-files | grep -q 'chronyd.service'; then
        SERVICE_NAME="chronyd"
    elif systemctl list-unit-files | grep -q 'chrony.service'; then
        SERVICE_NAME="chrony"
    else
        echo "Chrony service not found. Please check the installation."
        exit 1
    fi

    # Enable and start the appropriate Chrony service
    echo "Enabling and starting $SERVICE_NAME service..."
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME

    echo "Chrony installation and service configuration completed."
}

# Function to configure Chrony servers
configure_chrony_servers() {
    local servers_string=$1

    # Define possible locations for the Chrony configuration file
    local config_files=("/etc/chrony/chrony.conf" "/etc/chrony.conf")

    # Attempt to find the existing Chrony configuration file
    for file in "${config_files[@]}"; do
        if [[ -f $file ]]; then
            config_file=$file
            echo "Using Chrony configuration file at $config_file"
            break
        fi
    done

    if [[ -z $config_file ]]; then
        echo "Chrony configuration file not found, attempting to install Chrony..."
        install_chrony

        # Attempt to find the configuration file again after installation
        for file in "${config_files[@]}"; do
            if [[ -f $file ]]; then
                config_file=$file
                echo "Using Chrony configuration file at $config_file"
                break
            fi
        done

        if [[ -z $config_file ]]; then
            echo "Failed to locate Chrony configuration file after installation."
            exit 1
        fi
        echo "Using Chrony configuration file at $config_file"
    fi

    # Proceed with the configuration...
    # Backup the original Chrony configuration file
    sudo cp "$config_file" "$config_file.backup"

    # Comment out existing server or pool lines and add new ones
    sudo sed -i '/^pool / s/^/#/' "$config_file"
    sudo sed -i '/^server / s/^/#/' "$config_file"
    
    IFS=',' read -r -a servers_array <<< "$servers_string"
    
   # Check which Chrony service is available (chronyd or chrony)
    if systemctl list-unit-files | grep -q 'chronyd.service'; then
        SERVICE_NAME="chronyd"
    elif systemctl list-unit-files | grep -q 'chrony.service'; then
        SERVICE_NAME="chrony"
    else
        echo "Chrony service not found. Please check the installation."
        exit 1
    fi

    # Regular expression for validating an IP address and hostname
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    local hostname_regex='^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'

    # Stopping the Chrony service
    echo "Restarting Chrony service..."
    sudo systemctl stop $SERVICE_NAME

    # Process each server IP/hostname
    for server in "${servers_array[@]}"; do
        echo "Processing $server..."

        if [[ $server =~ $ip_regex || $server =~ $hostname_regex ]]; then
            echo "Adding $server to Chrony configuration."
            echo "server $server iburst" | sudo tee -a "$config_file" > /dev/null
            echo "Forcing synchronization with $server..."
            sudo chronyd -q 'server $server iburst'
        else
            echo "Warning: $server is not a valid IP address or hostname. Skipping."
        fi
    done


    sudo systemctl start $SERVICE_NAME

    echo "Chrony is now configured with the provided servers."
}

# Usage check
if [ $# -eq 0 ]; then
    echo "Usage: $0 'NTP_SERVER_IP1,NTP_SERVER_IP2,...'"
    exit 1
fi

configure_chrony_servers "$1"
