#!/bin/bash

# make_pinn_release.sh 17.01.1 "m_modem_hilink m_modem_android_tether m_nano m_wget m_crelay" "http://downloads.sourceforge.net/project/pinn/os/lede2R"

working_dir="/tmp"
os_list_lede_file="${working_dir}/os_list_lede.json"
script_dir=$(dirname $(readlink -f $0))

run_lede2rpi() {
  local raspberry_model="$1"

  echo "Creating files for model ${raspberry_model}"
  ${script_dir}/lede2rpi.sh\
  -m "${raspberry_model}"\
  -r "${lede_release}"\
  -s "/root/init_config.sh"\
  -b "/root/ipk"\
  -a "${modules_to_add}"\
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

# default = no modules
modules_to_add=${2:-"${m_none}"}

# default = user procount github url
os_list_binaries_url=${3:-"https://raw.githubusercontent.com/procount/pinn-os/master/os/lede2R"}

echo "Creating LEDE release '${lede_release}' files for PINN"
echo "os_list_binaries_url = ${os_list_binaries_url}"
echo "Meta modules list: '${modules_to_add}'"

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

