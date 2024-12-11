#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo 'This setup script must be run as root.'
    exit 1
fi

#set -eu

echo '========================================================================'
echo ' █████╗ ███╗   ██╗████████╗██╗ ██████╗██╗      ██████╗ ██╗   ██╗██████╗ '
echo '██╔══██╗████╗  ██║╚══██╔══╝██║██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗'
echo '███████║██╔██╗ ██║   ██║   ██║██║     ██║     ██║   ██║██║   ██║██║  ██║'
echo '██╔══██║██║╚██╗██║   ██║   ██║██║     ██║     ██║   ██║██║   ██║██║  ██║'
echo '██║  ██║██║ ╚████║   ██║   ██║╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝'
echo '╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ '
echo 'AntiCloud PickupBin Installation Script -- v0.0.1'
echo 'CS 576'
echo '========================================================================'
echo

_alert() {
    echo -e '>>>> \e[1m' "$@" '\e[0m <<<<'
}

_alert 'This script will setup AntiCloud services on your Raspberry Pi.'
_alert 'Press ENTER to continue: '
read -r



_setup_apt_packages() {
    _alert 'Installing required packages...'
    apt install -y docker.io docker-compose diceware libmicrohttpd-dev build-essential
}


filebrowser_host_port=8081
snapdrop_host_port=8080

filebrowser_docker_compose_yml='
services:
  filebrowser:
    image: filebrowser/filebrowser
    container_name: filebrowser
    restart: always
    volumes:
        - /opt/filebrowser/srv:/srv
        - /opt/filebrowser/filebrowser.db:/database/filebrowser.db
        - /opt/filebrowser/filebrowser.json:/.filebrowser.json
    ports:
        - 8081:80
'

filebrowser_systemd_service='
[Unit]
Description=filebrowser docker container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker-compose -f /opt/filebrowser/docker-filebrowser.yml up
ExecStop=/usr/bin/docker-compose -f /opt/filebrowser/docker-filebrowser.yml down

[Install]
WantedBy=default.target
'

filebrowser_config_json='
{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/database/filebrowser.db",
  "root": "/srv",
  "noauth": true
}
'

_setup_filebrowser() {
    echo
    _alert 'Configuring File Browser service...'
    _alert 'Creating /opt/filebrowser...'
    echo

    set +eu
    rm -rf /opt/filebrowser
    mkdir -p /opt/filebrowser/srv
    touch /opt/filebrowser/filebrowser.db
    echo "$filebrowser_config_json" > /opt/filebrowser/filebrowser.json
    echo "$filebrowser_docker_compose_yml" > /opt/filebrowser/docker-filebrowser.yml

    echo
    echo
    _alert 'Creating systemd service file so File Browser starts on boot...'
    echo
    echo "$filebrowser_systemd_service" > /etc/systemd/docker-filebrowser.service
    systemctl enable /etc/systemd/docker-filebrowser.service
    systemctl restart docker-filebrowser.service
}


snapdrop_systemd_service="
[Unit]
Description=snapdrop docker container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker-compose -f /opt/snapdrop/docker-compose.yml up
ExecStop=/usr/bin/docker-compose -f /opt/snapdrop/docker-compose.yml down

[Install]
WantedBy=default.target
"
_setup_snapdrop() {
    echo
    echo
    _alert 'Configuring Snapdrop service...'
    _alert 'Creating /opt/snapdrop...'
    echo

    set +eu
    rm -rf /opt/snapdrop
    mkdir /opt/snapdrop
    cd /opt
    git clone https://github.com/SnapDrop/snapdrop.git
    cd -

    chown -R anticloud:anticloud /opt/snapdrop

    echo
    echo
    _alert 'Creating, enabling, starting systemd service file so Snapdrop starts on boot...'
    echo
    echo "$snapdrop_systemd_service" > /etc/systemd/docker-snapdrop.service
    systemctl enable /etc/systemd/docker-snapdrop.service
    systemctl restart docker-snapdrop.service
}


splash_page_html='
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Anti-Cloud Landing Page</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            background: linear-gradient(135deg, #24292e, #17191c);
            color: white;
            text-align: center;
        }

        h1 {
            margin-bottom: 20px;
            font-size: 2.5rem;
        }

        .buttons {
            display: flex;
            gap: 20px;
        }

        .button {
            padding: 15px 30px;
            font-size: 1.2rem;
            background-color: #007acc;
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            transition: background-color 0.3s ease;
            text-decoration: none;
        }

        .button:hover {
            background-color: #005f99;
        }
    </style>
</head>
<body>
<h1>Welcome to Anti-Cloud!</h1>
<div class="buttons">
    <a href="http://10.42.0.1:8081" class="button">File Storage</a>
    <a href="http://10.42.0.1:8080" class="button">P2P File Transfer</a>
</div>
</body>
</html>
'

_done() {
    _alert "Installation is complete!"
    _alert "You can access the P2P file transfer service at http://10.42.0.1:8080"
    _alert "You can access the file storage service at http://10.42.0.1:8081"
}

_setup_hotspot() {
    echo
    echo
    _alert "Setting up WiFi hotspot..."
    echo

    ssid="AntiCloud$(openssl rand -hex 4)"
    local password="$(diceware --no-caps -n3 -d-)"
    

    # delete existing hotspot, create new one
    nmcli con delete AntiCloudHotspot
    nmcli con add type wifi ifname wlan0 con-name AntiCloudHotspot autoconnect yes ssid "$ssid"
    nmcli con modify AntiCloudHotspot 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
    nmcli con modify AntiCloudHotspot wifi-sec.key-mgmt wpa-psk
    nmcli con modify AntiCloudHotspot wifi-sec.psk "${password}"
    nmcli con up AntiCloudHotspot
    # set autoconnect
    nmcli dev wifi show-password
    _alert "Please save the SSID and password to write to your NFC tag later."
    _alert "Use WPA/WPA2 for the authentication type, and WEP for encryption type."
    _alert "Then, press ENTER to continue: "
    read -r
}


_setup_apt_packages
_setup_filebrowser
_setup_snapdrop
_setup_webui
_setup_hotspot
_done
