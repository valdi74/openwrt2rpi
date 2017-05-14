
LAN_IP="192.168.44.1"
SHUTDOWN_BUTTON_SCRIPT="/root/shutdown_button.sh"

uci set system.@system[0].timezone=CET-1CEST,M3.5.0,M10.5.0/3
uci commit system

uci set wireless.@wifi-device[0].disabled=0
uci set wireless.@wifi-device[0].channel=11
uci set wireless.@wifi-iface[0].ssid=DarthVader
uci set wireless.@wifi-iface[0].encryption=psk2
uci set wireless.@wifi-iface[0].key=secretpassword
uci commit wireless

uci set network.lan.ipaddr=${LAN_IP}
uci del network.wan
uci set network.wan=interface
uci set network.wan.proto=dhcp
uci set network.wan.ifname=eth1
uci commit network

echo "
${LAN_IP} ruter ruter.lan ruter.local
" >> /etc/hosts

cat <<'EOF' > "$SHUTDOWN_BUTTON_SCRIPT"
#!/bin/sh
GPIO_NUMBER=22
GPIO_DIR="/sys/class/gpio"
GPIO_BUTTON_DIR=${GPIO_DIR}/gpio${GPIO_NUMBER}
GPIO_BUTTON_VALUE=${GPIO_BUTTON_DIR}/value

echo "GPIO shutdown script:"
echo GPIO_NUMBER=${GPIO_NUMBER}
echo GPIO_DIR=${GPIO_DIR}
echo GPIO_BUTTON_DIR=${GPIO_BUTTON_DIR}
echo GPIO_BUTTON_VALUE=${GPIO_BUTTON_VALUE}

[ -d ${GPIO_BUTTON_DIR} ] || echo ${GPIO_NUMBER} > ${GPIO_DIR}/export
echo "in" > ${GPIO_BUTTON_DIR}/direction

while [ "$(cat ${GPIO_BUTTON_VALUE})" = 0 ]; do
  sleep 1
done

if [ "$(cat ${GPIO_BUTTON_VALUE})" = 1 ]; then
  sync
  echo "Button ${GPIO_NUMBER} = poweroff"
  poweroff
else
  echo "Problem with shutdown button ${GPIO_NUMBER}"
fi
EOF

chmod u+x "$SHUTDOWN_BUTTON_SCRIPT"

sed -i "/exit 0/i ${SHUTDOWN_BUTTON_SCRIPT} &" /etc/rc.local

sync
sleep 10
sync
reboot

