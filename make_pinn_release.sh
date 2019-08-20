#!/bin/bash

# make_pinn_release.sh 18.06.3 "m_modem_hilink m_modem_android_tether m_nano m_wget m_crelay" "http://downloads.sourceforge.net/project/pinn/os/lede2R"

working_dir="/tmp"
os_list_openwrt_file="${working_dir}/os_list_openwrt.json"
script_dir=$(dirname $(readlink -f $0))

run_openwrt2rpi() {
  local raspberry_model="$1"

  echo "Creating files for model ${raspberry_model}"
  ${script_dir}/openwrt2rpi.sh\
  -m "${raspberry_model}"\
  -r "${openwrt_release}"\
  -s "/root/init_config.sh"\
  -b "/root/ipk"\
  -a "${modules_to_add}"\
  -j "${os_list_binaries_url}"\
  -o "openwrt2R${raspberry_model}"\
  -d "${working_dir}"
}

if [ -z "$1" ]; then
  echo "  USAGE: $0 OpenWrt_release [list_of_module_sets] [os_list_binaries_url]"
  echo "Example: $0 18.06.3 \"m_modem_base m_modem_hilink m_modem_android_tether m_nano m_wget m_crelay\""
  exit 1
fi

openwrt_release=$1

# default = no modules
modules_to_add=${2:-"${m_none}"}

# default = user procount github url
os_list_binaries_url=${3:-"https://raw.githubusercontent.com/procount/pinn-os/master/os/lede2R"}

echo "Creating OpenWrt release '${openwrt_release}' files for PINN"
echo "os_list_binaries_url = ${os_list_binaries_url}"
echo "Meta modules list: '${modules_to_add}'"

cat <<'EOF' > "${os_list_openwrt_file}"
{
    "os_list": [
EOF

run_openwrt2rpi "Pi"
truncate -s-1 "${os_list_openwrt_file}"
echo "," >> "${os_list_openwrt_file}"
run_openwrt2rpi "Pi2"
truncate -s-1 "${os_list_openwrt_file}"
echo "," >> "${os_list_openwrt_file}"
run_openwrt2rpi "Pi3"
cat <<'EOF' >> "${os_list_openwrt_file}"
    ]
}
EOF

echo "OpenWrt release files for PINN created. You can find os_list here: ${os_list_openwrt_file}"

