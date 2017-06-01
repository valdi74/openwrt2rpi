#!/bin/bash

#defaults
program_version="1.09"
media_user_dir="/media/${USER}"
working_dir="/tmp"
lede_boot_part_size=28
lede_root_part_size=302
lede_os_name="LEDE"
boot_part_label="LEDE_boot"
root_part_label="LEDE_root"
modules_destination="/root/ipk"
pause_after_mount="N"
rc_local="/etc/rc.local"
wget_opts="q"
kpartx_opts=""
gzip_opts=""
stdout="/dev/null"
trap_signals="SIGHUP SIGINT SIGTERM ERR EXIT"
delete_temp_files="T"
script_dir=$(dirname $(readlink -f $0))

#test run (no img file downloading/decompress):
#DEBUG=T ./lede2rpi.sh -m Pi3 -r 17.01.1 -p -q -s /root/init_config.sh -i ~/tmp/my_lede_init.sh -b /root/ipk -a "kmod-usb2 librt libusb-1.0" -k 26 -l 302 -n LEDE_boot1 -e LEDE_root1 -o LEDE1

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
m_mt7601u="kmod-mac80211 mt7601u-firmware kmod-mt7601u"
m_nano="terminfo libncurses nano"
m_crelay="libusb-1.0 libftdi1 hidapi crelay"
m_wget="librt libpcre zlib libopenssl wget"
m_adblock="${m_wget} adblock"
m_all="${m_modem_all} m_nano m_crelay m_wget m_adblock"

add_module() {
  local new_mod="${1}"
  local found

  if [ "${new_mod:0:2}" == "m_" ]; then
    add_modules "${!new_mod}"
  else
    if [ -z "${modules_to_download}" ]; then
      modules_to_download="${new_mod}"
    else
      found=N
      for old_mod in ${modules_to_download}; do
        if [ "${old_mod}" == "${new_mod}" ]; then
          found=T
          break
        fi
      done
      [ "${found}" == "N" ] && modules_to_download="${modules_to_download} ${new_mod}"
    fi
  fi
}

add_modules() {
  local new_mod

  for new_mod in ${1}; do
    add_module "${new_mod}"
  done
}

colored_echo() {
  local color=$2
  if ! [[ $color =~ '^[0-9]$' ]] ; then
    case $(echo $color | tr '[:upper:]' '[:lower:]') in
      black) color=0 ;;
      red) color=1 ;;
      green) color=2 ;;
      yellow) color=3 ;;
      blue) color=4 ;;
      magenta) color=5 ;;
      cyan) color=6 ;;
      white|*) color=7 ;; # white or invalid color
    esac
  fi
  tput setaf $color
  [ "$3" == "bold" ] && tput bold
  echo -ne $1 1>&2
  tput sgr0
}

error_exit() {
  colored_echo "$1\n" red bold
  exit 1
}

print_usage() {
  echo -e "\n  Usage: ${0##*/} $1"
  example="example:"
  z=2
  while [ -n "${!z}" ]; do
    echo -e   "$example ${0##*/} ${!z}"
    example="        "
    let z+=1
  done
  echo
  exit 1
}

print_var_name_value() {
  if [ -z "$2" ]; then
    echo -ne "$1 = ${!1}\n"
  else
    colored_echo "$1 = ${!1}\n" "$2" "$3"
  fi
}

print_var_name_value_verbose() {
  if [ "${verbose}" == "T" ]; then
    print_var_name_value "$1" "$2" "$3"
  fi
}

print_info() {
  if [ ! "${quiet}" == "T" ]; then
    colored_echo "$1" ${2:-"green"}
  fi
}

ask() {
  local key_pressed

  read -n1 -r -p "$1 (Enter/y=yes) " key_pressed
  if [ -z "$key_pressed" ] || [ "$key_pressed" = "y" ]; then
    echo "Y"
  else
    echo "N"
  fi
  echo >&2
}

pause() {
  local message
  local key_pressed

  if [ -n "$1" ]; then
    message=$1
  else
    message="PRESS ENTER "
  fi

  echo
  read -r -p "$message" key_pressed
  echo
}

input_line() {
  local buffer

  read -r -p "$1" buffer
  echo $buffer
}

get_param_from_file() {
  shopt -s extglob
  while IFS='= ' read lhs rhs
  do
    if [[ ! $lhs =~ ^\ *# && -n $lhs && "$lhs" == "$2" ]]; then
        rhs="${rhs%%\#*}"    # Del in line right comments
        rhs="${rhs%%*( )}"   # Del trailing spaces
#        rhs="${rhs%\"*}"     # Del opening string quotes
#        rhs="${rhs#\"*}"     # Del closing string quotes
        sed -e 's/^"//' -e 's/"$//' <<<"$rhs"
#        echo "$rhs"
    fi
  done < $1
}

download() {
  local options="$1"
  local url="$2"
  local filename="$3"
  local description="$4"

  if [ -f "${filename}" ]; then
    print_info "${description} exists, not downloading.\n" yellow
  else
    print_info "Downloading ${description}..."
    # debug
    [ "$debug" != "T" ] && wget -${options}O "${filename}" "${url}"
    print_info "done\n"
  fi
}

bad_params=N
while getopts ":m:r:d:a:b:s:i:g:k:l:n:e:o:u:j:cqvpwth" opt; do
  case $opt in
    m) raspberry_model="$OPTARG"
    ;;
    r) lede_release="$OPTARG"
    ;;
    d) working_dir="$OPTARG"
    ;;
    a) modules_list="$OPTARG"
    ;;
    b) modules_destination="$OPTARG"
    ;;
    s) initial_script_path="$OPTARG"
    ;;
    i) include_initial_file="$OPTARG"
    ;;
    g) run_command_after_mount="$OPTARG"
    ;;
    k) lede_boot_part_size="$OPTARG"
    ;;
    l) lede_root_part_size="$OPTARG"
    ;;
    n) boot_part_label="$OPTARG"
    ;;
    e) root_part_label="$OPTARG"
    ;;
    o) lede_os_name="$OPTARG"
    ;;
    u) upgrade_partitions="$OPTARG"
    ;;
    j) os_list_binaries_url="$OPTARG"
    ;;
    c) run_initial_script_once=T
    ;;
    q) quiet=T
    ;;
    v) verbose=T
    ;;
    p) pause_after_mount=T
    ;;
    w) dont_generate_files=T
    ;;
    t) delete_temp_files=N
    ;;
    h) help=T
    ;;
    \?) echo "Invalid option -$OPTARG" >&2; bad_params=T
    ;;
  esac
done

if [ "$help" == "T" ]; then
  echo "
Usage:

lede2rpi.sh -m raspberry_model -r lede_release [OPTIONS]

OPTIONS:

-m raspberry_model
   raspberry_model=Pi|Pi2|Pi3, mandatory parameter

-r lede_release
   lede_release=snapshot|17.01.0|17.01.1|future_release_name, mandatory parameter

-d working_dir
   working_dir=<working_directory_path>, optional parameter, default=/tmp
   Directory to store temporary and final files.

-p
   optional parameter
   Pause after boot and root partitions mount. You can add/modify files on both partitions in /media/$USER/[MOUNT_NAME] directories.

-a modules_list
   modules_list='module1 module2 ...', optional parameter
   List of modules/modules sets to download and copy to root image into modules_destination directory.
   Currently available module sets:
    - m_modem_base - base modules for USB modems
    - m_modem_ras_ppp - RAS (ppp) USB modems
    - m_modem_ras_acm - RAS (ACM) USB modems
    - m_modem_ncm - NCM USB modems
    - m_modem_huawei_ncm - Huawei NCM USB modems
    - m_modem_qmi - QMI USB modems
    - m_modem_hilink - HiLink USB modems
    - m_modem_hostless - hostlessUSB modems
    - m_modem_directip - DirectIP USB modems
    - m_modem_mbim - MBIM USB modems
    - m_modem_HSO - HSO USB modems
    - m_modem_android_tether - Android tethering USB modem
    - m_modem_iphone_tether - iPhone tethering USB modem
    - m_modem_all - all above modem modules
    - m_nano - nano editor
    - m_crelay - crelay USB power switch
    - m_wget - full wget
    - m_adblock - LEDE adblock module (includes full wget)
    - m_all - all above modules
    - m_none - no modules download

-b modules_destination
   modules_destination=<ipk_directory_path>, optional parameter, default=/root/ipk
   Directory on LEDE root partition to copy downloaded modules from modules_list

-s initial_script_path
   initial_script_path=<initial_script_path>, optional parameter, default=none
   Path to store initial configuration script on LEDE root partition. Example: /root/init_config.sh

-i include_initial_file
   modules_list=<include_initial_script_path>, optional parameter
   Path to local script, to be included in initial configuration script initial_script_path.

-g run_command_after_mount
   run_command_after_mount=<command_to_run>, optional parameter
   Command to run after boot and root partitions mount.
   The command will receive two parameters: boot and root partitions mount directory.

-c
   optional parameter, default=no autorun initial script
   Run initial script initial_script_path once. Path to initial script will be added do /etc/rc.local and removed after first run.

-k lede_boot_part_size
   lede_boot_part_size=<boot_partition_size_in_mb>, optional parameter, default=25
   LEDE boot partition size in MB.

-l lede_root_part_size
   lede_root_part_size=<root_partition_size_in_mb>, optional parameter, default=300
   LEDE root partition size in MB.

-n boot_part_label
   boot_part_label=<boot_partition_label>, optional parameter, default=LEDE_boot
   LEDE boot partition label.

-e root_part_label
   root_part_label=<root_partition_label>, optional parameter, default=LEDE_root
   LEDE root partition label.

-o lede_os_name
   lede_os_name=<lede_os_name>, optional parameter, default=LEDE
   LEDE os name in os.json

-q
   optional parameter, default=no quiet
   quiet mode.

-v
   optional parameter, default=no verbose
   verbose mode.

-u upgrade_partitions
   upgrade_partitions='BOOT=<RPi_boot_dev>:<local_boot_dir>,ROOT=<RPi_root_dev>:<local_root_dir>', optional parameter
   Upgrade existing LEDE instalation. Use with care! You shouldn't use this option unless you know what you are doing.
   WARNING: all files from <local_boot_dir> and <local_root_dir> will be DELETED.
   example: -u BOOT=/dev/mmcblk0p6:/media/$USER/LEDE_boot,ROOT=/dev/mmcblk0p7:/media/$USER/LEDE_root
   Assume that:
    - boot partition on RPi is /dev/mmcblk0p6
    - boot partition is now mounted in /media/$USER/LEDE_boot
    - root partition on RPi is /dev/mmcblk0p7
    - root partition is now mounted in /media/$USER/LEDE_root

-w
   optional parameter, default=generate NOOBS/PINN files
   Don't generate NOOBS/PINN files in LEDE directory. Useful with -u (only upgrade).

-t
   optional parameter, default=delete temporary files
   Don't delete temporary files (LEDE image, ipk, etc.)

-j os_list_binaries_url
   optional parameter, default=<empty> -> don't generate 
   Create (append mode) os_list_lede.json for NOOBS/PINN on-line installation.
   File will be created in <working_dir> directory.
   Destination URL=<os_list_binaries_url><raspberry_model>/[os_setup_filename], exmaple:
   - os_list_binaries_url="http://downloads.sourceforge.net/project/pinn/os/lede2R"
   - raspberry_model="Pi2"
   Result URL for "os_info":
   "http://downloads.sourceforge.net/project/pinn/os/lede2RPi2/os.json"

-h
   Display help and exit.
"
  exit
fi

[ ! "${quiet}" == "T" ] && echo "LEDE2RPi version ${program_version}, RPi model=${raspberry_model}, LEDE release=${lede_release}"

[ -z "${raspberry_model}" ] && echo "Model not specified" && bad_params=T

[ -z "${lede_release}" ] && echo "LEDE release not specified" && bad_params=T

[ "${bad_params}" == "T" ] && print_usage "-m Pi|Pi2|Pi3 -r lede_release|snapshot [-d working_dir] [-p] [-v] [-q] [-w] [-t] [-a modules_list] [-b modules_destination] [-s initial_script_path] [-i include_initial_file] [-g run_command_after_mount] [-q] [-k lede_boot_part_size] [-l lede_root_part_size] [-n boot_part_label] [-e root_part_label] [-o lede_os_name] [-u upgrade_partitions]" "-m Pi3 -r 17.01.1" "-m Pi2 -r 17.01.0" "-m Pi  -r snapshot" "-h # help"

case "${raspberry_model}" in
  "Pi")  lede_subtarget="bcm2708"; raspberry_models="\"Pi Model\", \"Pi Compute Module\", \"Pi Zero\""; raspberry_hex_revisions="2,3,4,5,6,7,8,9,d,e,f,10,11,12,13,14,19,0092" ;;
  "Pi2") lede_subtarget="bcm2709"; raspberry_models="\"Pi 2\""; raspberry_hex_revisions="1040,1041" ;;
  "Pi3") lede_subtarget="bcm2710"; raspberry_models="\"Pi 3\""; raspberry_hex_revisions="2082" ;;
  *) error_exit "Unrecognized model: ${raspberry_model}"
esac

[ "$lede_release" == "snapshot" ] && lede_download_dir="snapshots" || lede_download_dir="releases/${lede_release}"
lede_download="https://downloads.lede-project.org/${lede_download_dir}/targets/brcm2708/${lede_subtarget}"
lede_image_compr_ext=".gz"
lede_image_mask="lede.*${lede_subtarget}.*\.img\\${lede_image_compr_ext}"
block_device_prefix="/dev/dm-"
raspberry_model_dir="lede2R${raspberry_model}"
working_sub_dir="${working_dir}/${raspberry_model_dir}_${lede_release}"
destination_dir="${working_sub_dir}/${raspberry_model_dir}"
noobs_boot_image="${destination_dir}/${boot_part_label}.tar"
noobs_root_image="${destination_dir}/${root_part_label}.tar"
lede_html="lede.html"
lede_init_tmp_file="${working_sub_dir}/lede_init.sh"
modules_download_dir="${working_sub_dir}/ipk"
repos_download_dir="${working_sub_dir}/repos"
lede_kernel_image="kernel*.img"
lede_version_file="usr/lib/os-release"
lede_kernel_ver_default="4.5"
lede_repo_config="/etc/opkg/distfeeds.conf"
upgrade_backup_dir="${working_sub_dir}/backup"
media_dir="${script_dir}/bin"
noobs_logo_file="${media_dir}/LEDE.png"
noobs_marketing_dir="${media_dir}/marketing"
noobs_marketing_name="marketing.tar"
noobs_partitions_config_file="partitions.json"
noobs_os_config_file="os.json"
noobs_icon_file="${lede_os_name}.png"
noobs_partition_setup_file="partition_setup.sh"
noobs_os_description="LEDE (OpenWrt) for the Raspberry ${raspberry_model}"
os_list_lede_file="${working_dir}/os_list_lede.json"

[ "$debug" == "T" ] && print_var_name_value DEBUG red bold

if [ "$verbose" == "T" ]; then
  wget_opts=""
  kpartx_opts="v"
  gzip_opts="v"
  stdout="/dev/stdout"
  quiet=N
  print_var_name_value_verbose destination_dir
  print_var_name_value_verbose lede_image_mask
  print_var_name_value_verbose raspberry_model
  print_var_name_value_verbose raspberry_models
  print_var_name_value_verbose lede_subtarget
  print_var_name_value_verbose lede_release
  print_var_name_value_verbose lede_download
  print_var_name_value_verbose upgrade_partitions
fi

if [ ! -z "$upgrade_partitions" ]; then
  upgrade_boot_config=$(echo "$upgrade_partitions" | cut -d, -f1)
  [ "${upgrade_boot_config:0:5}" != "BOOT=" ] && error_exit "Missing 'BOOT=' in upgrade config: ${upgrade_partitions}"

  upgrade_rpi_dev_boot=$(echo ${upgrade_boot_config:5} | cut -d\: -f1)
  print_var_name_value_verbose upgrade_rpi_dev_boot
  [ -z "$upgrade_rpi_dev_boot" ] && error_exit "Missing RPi device in upgrade BOOT config: ${upgrade_boot_config:5}"

  upgrade_dir_boot=$(echo ${upgrade_boot_config:5} | cut -d\: -f2)
  print_var_name_value_verbose upgrade_dir_boot
  [ -z "$upgrade_dir_boot" ] && error_exit "Missing local dir in upgrade BOOT config: ${upgrade_boot_config:5}"
  [ ! -d "$upgrade_dir_boot" ] && error_exit "Upgrade BOOT config: ${upgrade_dir_boot} is not a directory"

  upgrade_root_config=$(echo "$upgrade_partitions" | cut -d, -f2)
  [ "${upgrade_root_config:0:5}" != "ROOT=" ] && error_exit "Missing 'ROOT=' in upgrade config: ${upgrade_partitions}"

  upgrade_rpi_dev_root=$(echo ${upgrade_root_config:5} | cut -d\: -f1)
  print_var_name_value_verbose upgrade_rpi_dev_root
  [ -z "$upgrade_rpi_dev_root" ] && error_exit "Missing RPi device in upgrade ROOT config: ${upgrade_root_config:5}"

  upgrade_dir_root=$(echo ${upgrade_root_config:5} | cut -d\: -f2)
  print_var_name_value_verbose upgrade_dir_root
  [ -z "$upgrade_dir_root" ] && error_exit "Missing local dir in upgrade ROOT config: ${upgrade_root_config:5}"
  [ ! -d "$upgrade_dir_root" ] && error_exit "Upgrade ROOT config: ${upgrade_dir_root} is not a directory"

  ANSWER=$(input_line "Are you sure to delete all files from $upgrade_dir_boot and $upgrade_dir_root and upgrade LEDE instalation? Enter 'yes': ")
  [ "$ANSWER" != "yes" ] && error_exit "User abort"
fi

unmount_image() {
  if [ -d "$2" ]; then
    print_info "Unmounting $1 -> $2\n"
    while lsof -p ^$$ "$2" ; do
      pause "Above processes are blocking directory $2. Release the lock and press ENTER."
    done

    udisksctl unmount --block-device "$1" > "${stdout}"
    sleep 1
  fi
}

unmount_images() {
  #cd "${working_dir}"
  sync

  unmount_image "${block_device_root}" "${root_partition_dir}"
  unmount_image "${block_device_boot}" "${boot_partition_dir}"

  if [ ! -z "${lede_image_decompr}"  ]; then
    if sudo kpartx -l${kpartx_opts} "${working_sub_dir}/${lede_image_decompr}" | grep -vq "loop deleted"; then
      print_info "Deleting device maps from ${working_sub_dir}/${lede_image_decompr}\n"
      sudo kpartx -d${kpartx_opts} "${working_sub_dir}/${lede_image_decompr}" > "${stdout}"
    fi
  fi
}

clean_and_exit() {
  if [ -z "${cleaned}" ]; then
    print_info "Cleaning\n"
    unmount_images
    cleaned=T
    error_exit "$1"
  fi
}

trap 'clean_and_exit "ERROR COMMAND: $BASH_COMMAND in line $LINENO"' $trap_signals

mkdir -p "${working_sub_dir}"

download "${wget_opts}" "${lede_download}" "${working_sub_dir}/${lede_html}" "LEDE html page"

lede_image_compr=$(grep -o '"'${lede_image_mask}'"' "${working_sub_dir}/${lede_html}" | grep -o "${lede_image_mask}")

[ -z "${lede_image_compr}" ] && clean_and_exit "Can't get LEDE image name"
print_var_name_value_verbose lede_image_compr

lede_release_date=$(grep -o '<td class="d">.*</td>' "${working_sub_dir}/${lede_html}" | head -n1)
lede_release_date=$(date -d"${lede_release_date:14: -5}" +%Y-%m-%d)
print_var_name_value_verbose lede_release_date

download "${wget_opts}" "${lede_download}/${lede_image_compr}" "${working_sub_dir}/${lede_image_compr}" "LEDE image"

print_info "Decompressing LEDE image..."
# debug
[ "$debug" != "T" ] && gzip -dkf${gzip_opts} "${working_sub_dir}/${lede_image_compr}"
print_info "done\n"

lede_image_decompr=$(basename "${lede_image_compr}" "${lede_image_compr_ext}")

[ -z "${lede_image_decompr}" ] && clean_and_exit "Can't unpack LEDE image"

if [ "$verbose" == "T" ]; then
  print_var_name_value_verbose lede_image_decompr
  parted "${working_sub_dir}/${lede_image_decompr}" print
  print_var_name_value_verbose lede_boot_part_size
  print_var_name_value_verbose lede_root_part_size
fi

for i in $(seq 0 99); do
  block_device_boot="${block_device_prefix}${i}"
  [ ! -e "${block_device_boot}" ] && break
  block_device_boot=""
done

[ -z "${block_device_boot}" ] && error_exit "Can't evaluate block_device_boot"

for i in $(seq $((i+1)) 99); do
  block_device_root="${block_device_prefix}${i}"
  [ ! -e "${block_device_root}" ] && break
  block_device_root=""
done

[ -z "${block_device_root}" ] && error_exit "Can't evaluate block_device_root"

print_info "Create device maps from ${working_sub_dir}/${lede_image_decompr}\n"
sudo kpartx -sa${kpartx_opts} "${working_sub_dir}/${lede_image_decompr}"
sleep 1

boot_uuid=$(udisksctl mount --block-device "${block_device_boot}" | grep -o "${media_user_dir}/.*")
boot_uuid=$(basename "${boot_uuid}" .)
[ -z "${boot_uuid}" ] && clean_and_exit "Can't evaluate boot_uuid name"
print_var_name_value_verbose boot_uuid
boot_partition_dir="${media_user_dir}/${boot_uuid}"

root_uuid=$(udisksctl mount --block-device "${block_device_root}" | grep -o "${media_user_dir}/.*")
root_uuid=$(basename "${root_uuid}" .)
[ -z "${root_uuid}" ] && clean_and_exit "Can't evaluate root_uuid name"
print_var_name_value_verbose root_uuid
root_partition_dir="${media_user_dir}/${root_uuid}"

lede_kernel_ver=$(grep -ao "Linux version [0-9]\.[0-9]\{1,2\}\.[0-9]\{1,3\}" "${boot_partition_dir}"/${lede_kernel_image} | head -n1)
lede_kernel_ver="${lede_kernel_ver:14}"
[ -z "${lede_kernel_ver}" ] && lede_kernel_ver="${lede_kernel_ver_default}"
print_var_name_value_verbose lede_kernel_ver

cat <<EOF > "${lede_init_tmp_file}"
#!/bin/sh
EOF

if [ ! -z "${modules_list}" ]; then
  print_info "Meta modules to decode: '${modules_list}'\n"
  add_modules "${modules_list}"
  print_info "Downloading modules: '${modules_to_download}' into ${modules_destination} directory on LEDE root partition\n"

  #[ -d "${repos_download_dir}" ] && print_info "Warning: directory ${repos_download_dir} exists. Existing repos will not be downloaded.\n" yellow
  #[ -d "${modules_download_dir}" ] && print_info "Warning: directory ${modules_download_dir} exists. Existing files will not be downloaded.\n" yellow

  mkdir -p "${repos_download_dir}" "${modules_download_dir}"
  #rm -f "${repos_download_dir}"/* "${modules_download_dir}"/* #2>/dev/null

  i=1
#  for repo_url in $(grep -o 'http://.*' "${root_partition_dir}${lede_repo_config}"); do
  for repo_name_url in $(cut -f2,3 -d" " --output-delimiter="@" <"${root_partition_dir}${lede_repo_config}"); do
    repo_filename="${repos_download_dir}/${i}_${repo_name_url%%@*}.html"
    repo_url="${repo_name_url#*@}"
    download "${wget_opts}" "${repo_url}" "${repo_filename}" "LEDE repository ${repo_url}"
    echo -e "\n${repo_url}" >> "${repo_filename}"
    ((i++))
  done

  modules_downloaded=0
  for module in $modules_to_download; do
    package_name=$(grep -oP '(?<=<a href=")'${module}'_.*?\.ipk(?=">)' "${repos_download_dir}"/*)

    if [ -z "${package_name}" ]; then
      print_info "Can't find module ${module} in repos\n" "red"
    else
      repo_filename="${package_name%%:*}"
      package_name="${package_name#*:}"
      repo_url=$(tail -n1 "${repo_filename}")
      download "${wget_opts}" "${repo_url}/${package_name}" "${modules_download_dir}/${package_name}" "module ${package_name}"
      echo 'opkg install "'${modules_destination}'/'${package_name}'"' >> "${lede_init_tmp_file}"
      ((modules_downloaded++)) && true
    fi
  done
  echo '# rm '${modules_destination}'/*.ipk' >> "${lede_init_tmp_file}"
  echo '# rmdir '${modules_destination} >> "${lede_init_tmp_file}"

  sudo cp -R "${modules_download_dir}/." "${root_partition_dir}/${modules_destination}"
  modules_count=$(wc -w <<<"$modules_to_download")
  [ "${modules_downloaded}" -ne "${modules_count}" ] && print_color="red" || print_color=""
  print_info "Modules downloaded/all: ${modules_downloaded}/${modules_count}\n" "${print_color}"
fi

if [ ! -z "${run_initial_script_once}" ]; then
  print_info "Sheduling one run of initial script using LEDE ${rc_local}\n"

  echo 'sed -i "/#lede2rpi_delete/d" '${rc_local} >> "${lede_init_tmp_file}"

  sudo sed -i "/exit 0/i ${initial_script_path} #lede2rpi_delete" "${root_partition_dir}${rc_local}"
fi

if [ ! -z "${include_initial_file}" ]; then
  print_info "Including local initial file ${include_initial_file}\n"

  cat "${include_initial_file}" >> "${lede_init_tmp_file}"
fi

if [ ! -z "$initial_script_path" ]; then
  print_info "Creating initial script ${initial_script_path} on LEDE root partition\n"

  sudo cp "${lede_init_tmp_file}" "${root_partition_dir}/${initial_script_path}"
  sudo chmod u+x "${root_partition_dir}/$initial_script_path"
fi

if [ ! -z "$run_command_after_mount" ]; then
  print_info "Executing user command: ${run_command_after_mount}\n"
  $run_command_after_mount "${boot_partition_dir}" "${root_partition_dir}"
  print_info "User command finished\n"
fi

[ "$pause_after_mount" == "T" ] && pause "Now you can modify files in boot (${boot_partition_dir}) and root (${root_partition_dir}) partitions. Press ENTER when done."

if [ -z "$dont_generate_files" ]; then
  mkdir -p "${destination_dir}"
  rm -f "${destination_dir}"/* #2>/dev/null

  tar -cpf "${noobs_boot_image}" -C "${boot_partition_dir}" . || clean_and_exit "tar boot image failed"
  boot_tar_size=$(du -m "${noobs_boot_image}" | cut -f1) #ls "${noobs_boot_image}" -l --block-size=1MB
  print_var_name_value_verbose boot_tar_size
  print_info "xz compressing partition boot..."
  xz -f -9 -e "${noobs_boot_image}"
  print_info "done\n"

  lede_version_id=$(get_param_from_file "${root_partition_dir}/${lede_version_file}" VERSION_ID)
  lede_build_id=$(get_param_from_file "${root_partition_dir}/${lede_version_file}" BUILD_ID)
  lede_version="${lede_version_id} ${lede_build_id}"
  print_var_name_value_verbose lede_version

  sudo tar -cpf "${noobs_root_image}" -C "${root_partition_dir}" . --exclude=proc/* --exclude=sys/* --exclude=dev/pts/* || clean_and_exit "tar root image failed"
  sudo chown ${USER}:${USER} "${noobs_root_image}"
  root_tar_size=$(du -m "${noobs_root_image}" | cut -f1)
  print_var_name_value_verbose root_tar_size
  print_info "xz compressing partition root..."
  xz -f -9 -e "${noobs_root_image}"
  print_info "done\n"

  ##################################################################### partition_setup.sh
  print_info "Creating ${noobs_partition_setup_file}\n"
  cat <<'EOF' > "${destination_dir}/${noobs_partition_setup_file}"
#!/bin/sh

set -ex

if [ -z "$part1" ] || [ -z "$part2" ]; then
  printf "Error: missing environment variable part1 or part2\n" 1>&2
  exit 1
fi

mkdir -p /tmp/1 /tmp/2

mount "$part1" /tmp/1
mount "$part2" /tmp/2

sed /tmp/1/cmdline.txt -i -e "s|root=/dev/[^ ]*|root=${part2}|"
sed /tmp/2/etc/fstab -i -e "s|^.* / |${part2}  / |"
sed /tmp/2/etc/fstab -i -e "s|^.* /boot |${part1}  /boot |"
sed /tmp/2/lib/preinit/79_move_config -i -e "s|BOOTPART=/dev/[^ ]*|BOOTPART=${part1}|"

umount /tmp/1
umount /tmp/2
EOF
  ##################################################################### partitions.json
  print_info "Creating ${noobs_partitions_config_file}\n"
  cat <<EOF > "${destination_dir}/${noobs_partitions_config_file}"
{
  "partitions": [
    {
      "label": "${boot_part_label}",
      "filesystem_type": "FAT",
      "partition_size_nominal": ${lede_boot_part_size},
      "want_maximised": false,
      "uncompressed_tarball_size": ${boot_tar_size}
    },
    {
      "label": "${root_part_label}",
      "filesystem_type": "ext4",
      "partition_size_nominal": ${lede_root_part_size},
      "want_maximised": false,
      "mkfs_options": "-O ^huge_file",
      "uncompressed_tarball_size": ${root_tar_size}
    }
  ]
}
EOF
  ##################################################################### os.json
  print_info "Creating ${noobs_os_config_file}\n"
  cat <<EOF > "${destination_dir}/${noobs_os_config_file}"
{
  "name": "${lede_os_name}",
  "version": "${lede_version}",
  "release_date": "${lede_release_date}",
  "kernel": "${lede_kernel_ver}",
  "description": "${noobs_os_description}",
  "url": "${lede_download}",
  "supported_hex_revisions": "${raspberry_hex_revisions}",
  "supported_models": [
        ${raspberry_models}
  ],
  "feature_level": 0
}
EOF
  ##################################################################### LOGO
  print_info "Creating ${noobs_icon_file}\n"
  cp "${noobs_logo_file}" "${destination_dir}/${noobs_icon_file}"
  ##################################################################### marketing
  print_info "Creating ${noobs_marketing_name}\n"
  tar -cpf "${destination_dir}/${noobs_marketing_name}" -C "${noobs_marketing_dir}" .
  #####################################################################
  print_info "\nLEDE files for NOOBS are stored in ${destination_dir} directory.\nNow you can copy directory LEDE to NOOBS/PINN SD card into /os folder\n\n"

  if [ ! -z "$os_list_binaries_url" ]; then
    print_info "Appending new os to ${os_list_lede_file} file\n"
    os_list_binaries_url_model="${os_list_binaries_url}${raspberry_model}"

    cat <<EOF >> "${os_list_lede_file}"
        {
            "os_name":	    "${lede_os_name}",
            "description":  "${noobs_os_description}",
            "release_date": "${lede_release_date}",
            "feature_level": 0,
            "supported_hex_revisions": "${raspberry_hex_revisions}",
            "supported_models": [
              ${raspberry_models}
            ],
            "os_info":         "${os_list_binaries_url_model}/${noobs_os_config_file}",
            "partitions_info": "${os_list_binaries_url_model}/${noobs_partitions_config_file}",
            "icon":            "${os_list_binaries_url_model}/${noobs_icon_file}",
            "marketing_info":  "${os_list_binaries_url_model}/${noobs_marketing_name}",
            "partition_setup": "${os_list_binaries_url_model}/${noobs_partition_setup_file}",
            "tarballs": [
                               "${os_list_binaries_url_model}/${boot_part_label}.tar.xz",
                               "${os_list_binaries_url_model}/${root_part_label}.tar.xz"
            ],
            "nominal_size": 325
        }
EOF
    print_info "Creating ${raspberry_model_dir}.tar\n"
    tar -cf "${working_sub_dir}/${raspberry_model_dir}_${lede_release}.tar" -C "${working_sub_dir}" "${raspberry_model_dir}"
  fi
fi

if [ ! -z "$upgrade_partitions" ]; then
  mkdir -p "${upgrade_backup_dir}" "${upgrade_backup_dir}/etc"

  print_info "Upgrading boot partition\n"
  cp "${upgrade_dir_boot}/cmdline.txt" "${upgrade_backup_dir}"
  cp "${upgrade_dir_boot}/os_config.json" "${upgrade_backup_dir}"
  sudo find "${upgrade_dir_boot}" -mindepth 1 -delete

  sudo cp -a "${boot_partition_dir}/." "${upgrade_dir_boot}"
  sudo sed "${upgrade_dir_boot}/cmdline.txt" -i -e "s|root=/dev/[^ ]*|root=${upgrade_rpi_dev_root}|"
  sudo cp "${upgrade_backup_dir}/os_config.json" "${upgrade_dir_boot}"

  print_info "Upgrading root partition\n"
  sudo cp -a "${upgrade_dir_root}/etc" "${upgrade_backup_dir}"
  sudo find "${upgrade_dir_root}" -mindepth 1 -delete

  sudo cp -a "${root_partition_dir}/." "${upgrade_dir_root}"
  sudo sed "${upgrade_dir_root}/etc/fstab" -i -e "s|^.* / |${upgrade_rpi_dev_root}  / |"
  sudo sed "${upgrade_dir_root}/etc/fstab" -i -e "s|^.* /boot |${upgrade_rpi_dev_boot}  /boot |"

  print_info "\nLEDE instalation in ${upgrade_dir_boot} and ${upgrade_dir_root} upgraded.\nBackup files you can find in directory ${upgrade_backup_dir}\n\n"
fi

trap - $trap_signals

unmount_images

if [ "$delete_temp_files" == "T" ]; then
  print_info "Removing temporary files from ${working_sub_dir}\n"
  rm "${working_sub_dir}/${lede_image_decompr}"
  rm "${working_sub_dir}/${lede_html}"
  if [ ! -z "$modules_list" ]; then
    rm -f "${modules_download_dir}"/* "${repos_download_dir}"/* #2>/dev/null
    rmdir "${modules_download_dir}" "${repos_download_dir}"
  fi
  rm "${lede_init_tmp_file}"
fi

