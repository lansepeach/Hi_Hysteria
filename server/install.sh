#!/bin/bash
echo -e "Downloading hihy (Hysteria2)..."
wget -q --no-check-certificate -O /usr/bin/hihy https://raw.githubusercontent.com/lansepeach/Hi_Hysteria/refs/heads/main/server/hy2.sh && chmod +x /usr/bin/hihy
/usr/bin/hihy
