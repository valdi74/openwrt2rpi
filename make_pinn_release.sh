#!/bin/bash

# make_pinn_release.sh 17.01.1 "m_modem_hilink m_modem_android_tether m_nano m_wget m_crelay" "http://downloads.sourceforge.net/project/pinn/os/lede2R"

working_dir="/tmp"
os_list_lede_file="${working_dir}/os_list_lede.json"
script_dir=$(dirname $(readlink -f $0))

# USB modems and modules needed
#        BASE (all): (kmod-usb-core) kmod-usb-ehci kmod-usb2 librt libusb-1.0 usb-modeswitch
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
m_modem_base="kmod-usb-ehci kmod-usb2 librt libusb-1.0 usb-modeswitch"
m_modem_ras_ppp="${m_modem_base} chat comgt kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-option"
m_modem_ras_acm="${m_modem_base} chat comgt kmod-usb-acm"
m_modem_ncm="${m_modem_base} chat wwan comgt-ncm kmod-usb-net-cdc-ncm kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-option kmod-usb-wdm kmod-usb-net-huawei-cdc-ncm"
m_modem_huawei_ncm="${m_modem_base} chat wwan comgt-ncm kmod-usb-net-cdc-ncm kmod-usb-wdm kmod-usb-net-huawei-cdc-ncm"
m_modem_qmi="${m_modem_base} kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan libubox libjson-c libblobmsg-json wwan uqmi"
m_modem_hilink="${m_modem_base} kmod-mii kmod-usb-net kmod-usb-net-cdc-ether"
m_modem_hostless="${m_modem_base} kmod-mii kmod-usb-net kmod-usb-net-cdc-ether kmod-usb-net-rndis"
m_modem_directip="${m_modem_base} kmod-usb-net-sierrawireless comgt-directip"
m_modem_mbim="${m_modem_base} kmod-usb-net kmod-usb-wdm kmod-usb-net-cdc-ncm kmod-usb-net-cdc-mbim wwan umbim"
m_modem_HSO="${m_modem_base} comgt kmod-usb-net kmod-usb-net-hso"
m_modem_android_tether="${m_modem_base} kmod-usb-net kmod-usb-net-cdc-ether kmod-usb-net-rndis"
m_modem_iphone_tether="${m_modem_base} kmod-usb-net kmod-usb-net-ipheth libxml2 libplist zlib libusbmuxd libopenssl libimobiledevice usbmuxd"
m_modem_all="${m_modem_ras_ppp} ${m_modem_ras_acm} ${m_modem_ncm} ${m_modem_huawei_ncm} ${m_modem_qmi} ${m_modem_hilink} ${m_modem_hostless} ${m_modem_directip} ${m_modem_mbim} ${m_modem_HSO} ${m_modem_android_tether} ${m_modem_iphone_tether}"
# other modules
m_nano="terminfo libncurses nano"
m_crelay="libusb-1.0 libftdi1 hidapi crelay"
m_wget="libpcre zlib libopenssl wget"
m_adblock="${m_wget} adblock"
m_all="${m_modem_all} m_nano m_crelay m_wget m_adblock"

#modules_list="kmod-usb-ehci kmod-usb2 librt libusb-1.0 usb-modeswitch kmod-mii kmod-usb-net kmod-usb-net-cdc-ether terminfo libncurses nano libftdi1 hidapi crelay"

add_module() {
  local module_to_add
  local found
  local new_mod

  new_mod="${1}"

  if [ "${new_mod:0:2}" == "m_" ]; then
    add_modules "${!new_mod}"
  else
    if [ -z "${modules_list}" ]; then
      modules_list="${new_mod}"
    else
      found=N
      for old_mod in ${modules_list}; do
        if [ "${old_mod}" == "${new_mod}" ]; then
          found=T
          break
        fi
      done
      [ "${found}" == "N" ] && modules_list="${modules_list} ${new_mod}"
    fi
  fi
}

add_modules() {
 local new_mod

  for new_mod in ${1}; do
    add_module "${new_mod}"
  done
}

run_lede2rpi() {
  local raspberry_model="$1"

  echo "Creating files for model ${raspberry_model}"
  ${script_dir}/lede2rpi.sh\
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
  echo "  USAGE: $0 LEDE_release [list_of_module_sets] [os_list_binaries_url]"
  echo "Example: $0 17.01.1 \"m_modem_base m_modem_hilink m_modem_android_tether m_nano m_wget m_crelay\""
  exit 1
fi

lede_release=$1

# default = add all defined modules
modules_to_add=${2:-"${m_none}"}

# default = user procount github url
os_list_binaries_url=${3:-"https://raw.githubusercontent.com/procount/pinn-os/master/os/lede2R"}

modules_list=""
add_modules "${modules_to_add}"

echo "Creating LEDE release '${lede_release}' files for PINN"
echo "os_list_binaries_url = ${os_list_binaries_url}"
#echo "Meta modules list: '${modules_to_add}'"
echo "Modules to download to SD card:"
echo "${modules_list}"
exit
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

