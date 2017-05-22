#!/bin/bash

# make_pinn_release.sh 17.01.1 "http://downloads.sourceforge.net/project/pinn/os/lede2R"

working_dir="/tmp"
os_list_lede_file="${working_dir}/os_list_lede.json"

# exmaple: hilink modems, nano and crelay
# modules_to_add="m_modem_base m_modem_hilink m_nano m_crelay"

# add all defined modules
modules_to_add="m_modem_ras_ppp m_modem_ras_acm m_modem_ncm m_modem_huawei_ncm m_modem_qmi m_modem_hilink m_modem_hostless m_modem_mbim m_modem_HSO m_modem_android_tether m_modem_iphone_tether m_nano m_crelay"

# USB modems and modules needed
#        BASE (all): (kmod-usb-core) kmod-usb2 librt libusb-1.0 usb-modeswitch
#         RAS (ppp): chat comgt kmod-usb-serial (kmod-usb-serial-wwan) kmod-usb-serial-option
#         RAS (ACM): chat comgt kmod-usb-acm
#               NCM: chat (wwan) comgt-ncm kmod-usb-net-cdc-ncm kmod-usb-serial (kmod-usb-serial-wwan) kmod-usb-serial-option (kmod-usb-wdm) kmod-usb-net-huawei-cdc-ncm
#        Huawei NCM: chat (wwan) comgt-ncm (kmod-usb-net-cdc-ncm kmod-usb-wdm) kmod-usb-net-huawei-cdc-ncm
#               QMI: (kmod-usb-net kmod-usb-wdm) kmod-usb-net-qmi-wwan (libubox libjson-c libblobmsg-json wwan) uqmi 
#            HiLink: (kmod-mii kmod-usb-net) kmod-usb-net-cdc-ether
#          hostless: (kmod-mii kmod-usb-net kmod-usb-net-cdc-ether) kmod-usb-net-rndis
#          DirectIP: (kmod-usb-net) kmod-usb-net-sierrawireless (comgt kmod-usb-serial kmod-usb-serial-sierrawireless) comgt-directip
#              MBIM: (kmod-usb-net, kmod-usb-wdm, kmod-usb-net-cdc-ncm) kmod-usb-net-cdc-mbim (wwan) umbim
#               HSO: comgt [comgt-hso] kmod-usb-net kmod-usb-net-hso
# Android tethering: (kmod-usb-net kmod-usb-net-cdc-ether) kmod-usb-net-rndis
#  iPhone tethering: (kmod-usb-net) kmod-usb-net-ipheth (libxml2 libplist zlib libusbmuxd libopenssl libimobiledevice) usbmuxd

# modules set definitions
m_modem_base="kmod-usb2 librt libusb-1.0 usb-modeswitch"
m_modem_ras_ppp="chat comgt kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-option"
m_modem_ras_acm="chat comgt kmod-usb-acm"
m_modem_ncm="chat wwan comgt-ncm kmod-usb-net-cdc-ncm kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-option kmod-usb-wdm kmod-usb-net-huawei-cdc-ncm"
m_modem_huawei_ncm="chat wwan comgt-ncm kmod-usb-net-cdc-ncm kmod-usb-wdm kmod-usb-net-huawei-cdc-ncm"
m_modem_qmi="kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan libubox libjson-c libblobmsg-json wwan uqmi"
m_modem_hilink="kmod-mii kmod-usb-net kmod-usb-net-cdc-ether"
m_modem_hostless="kmod-mii kmod-usb-net kmod-usb-net-cdc-ether kmod-usb-net-rndis"
m_modem_mbim="kmod-usb-net kmod-usb-wdm kmod-usb-net-cdc-ncm kmod-usb-net-cdc-mbim wwan umbim"
m_modem_HSO="comgt kmod-usb-net kmod-usb-net-hso"
m_modem_android_tether="kmod-usb-net kmod-usb-net-cdc-ether kmod-usb-net-rndis"
m_modem_iphone_tether="kmod-usb-net kmod-usb-net-ipheth libxml2 libplist zlib libusbmuxd libopenssl libimobiledevice usbmuxd"
# other modules
m_nano="terminfo libncurses nano"
m_crelay="libusb-1.0 libftdi1 hidapi crelay"

#modules_list="kmod-usb2 librt libusb-1.0 usb-modeswitch kmod-mii kmod-usb-net kmod-usb-net-cdc-ether terminfo libncurses nano libftdi1 hidapi crelay"

add_modules() {
  local found

  if [ -z "${modules_list}" ]; then
    modules_list="${1}"
  else
    for new_mod in ${1}; do
      found=N
      for old_mod in ${modules_list}; do
        if [ "${old_mod}" == "${new_mod}" ]; then
          found=T
          break
        fi
      done
      [ "${found}" == "N" ] && modules_list="${modules_list} ${new_mod}"
    done
  fi
}

add_all_modules() {
  modules_list=""
  for list in ${modules_to_add}; do
    add_modules "${!list}"
  done
}

run_lede2rpi() {
  local raspberry_model="$1"

  echo "Creating files for model ${raspberry_model}"
  ./lede2rpi.sh\
  -m "${raspberry_model}"\
  -r "${lede_release}"\
  -s "/root/init_config.sh"\
  -b "/root/ipk"\
  -a "${modules_list}"\
  -j "${os_list_binaries_url}"\
  -o "lede2R${raspberry_model}"\
  -d "${working_dir}"
}

if [ -z "$1" ]; then
  echo "USAGE: $0 LEDE_release [os_list_binaries_url]"
  exit 1
fi

lede_release=$1
os_list_binaries_url=${2:-"http://downloads.sourceforge.net/project/pinn/os/lede2R"}

add_all_modules

echo "Creating LEDE release ${lede_release} files for PINN (os_list_binaries_url=${os_list_binaries_url})"
echo "Modules to download to SD card: '${modules_list}'"

cat <<'EOF' > "${os_list_lede_file}"
{
    "os_list": [
EOF

run_lede2rpi "Pi"
truncate -s-1 "${os_list_lede_file}"
echo "," >> "${os_list_lede_file}"
run_lede2rpi "Pi2"
truncate -s-1 "${os_list_lede_file}"
echo "," >> "${os_list_lede_file}"
run_lede2rpi "Pi3"
cat <<'EOF' >> "${os_list_lede_file}"
    ]
}
EOF

echo "LEDE release files for PINN created. You can find os_list here: ${os_list_lede_file}"

