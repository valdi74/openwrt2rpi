#!/bin/bash

#defaults
PROGRAM_VERSION="1.06"
MEDIA_USER_DIR="/media/${USER}"
WORKING_DIR="/tmp"
LEDE_BOOT_PART_SIZE=25
LEDE_ROOT_PART_SIZE=300
LEDE_OS_NAME="LEDE"
BOOT_PART_LABEL="LEDE_boot"
ROOT_PART_LABEL="LEDE_root"
MODULES_DESTINATION="/root/ipk/"
PAUSE_AFTER_MOUNT="N"
RC_LOCAL="/etc/rc.local"
WGET_OPTS="q"
KPARTX_OPTS=""
GZIP_OPTS=""
STDOUT="/dev/null"
TRAP_SIGNALS="SIGHUP SIGINT SIGTERM ERR EXIT"
DELETE_TEMP_FILES="T"

#test run (no img file downloading/decompress):
#DEBUG=T ./lede2rpi.sh -m Pi3 -r 17.01.1 -p -q -s /root/init_config.sh -i ~/tmp/my_lede_init.sh -b /root/ipk -a "kmod-usb2 librt libusb-1.0" -k 26 -l 302 -n LEDE_boot1 -e LEDE_root1 -o LEDE1

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
  if [ "${VERBOSE}" == "T" ]; then
    print_var_name_value "$1" "$2" "$3"
  fi
}

print_info() {
  if [ ! "${QUIET}" == "T" ]; then
    colored_echo "$1" green
  fi
}

ask() {
  local KEY_PRESSED

  read -n1 -r -p "$1 (Enter/y=yes) " KEY_PRESSED
  if [ -z "$KEY_PRESSED" ] || [ "$KEY_PRESSED" = "y" ]; then
    echo "Y"
  else
    echo "N"
  fi
  echo >&2
}

pause() {
  local MESSAGE
  local KEY_PRESSED

  if [ -n "$1" ]; then
    MESSAGE=$1
  else
    MESSAGE="PRESS ENTER "
  fi

  echo
  read -r -p "$MESSAGE" KEY_PRESSED
  echo
}

input_line() {
  local BUFFER

  read -r -p "$1" BUFFER
  echo $BUFFER
}

get_param_from_file() {
  shopt -s extglob
  while IFS='= ' read lhs rhs
  do
    if [[ ! $lhs =~ ^\ *# && -n $lhs && "$lhs" == "$2" ]]; then
        rhs="${rhs%%\#*}"    # Del in line right comments
        rhs="${rhs%%*( )}"   # Del trailing spaces
        rhs="${rhs%\"*}"     # Del opening string quotes
        rhs="${rhs#\"*}"     # Del closing string quotes
        echo "$rhs"
    fi
  done < $1
}

BAD_PARAMS=N
while getopts ":m:r:d:a:b:s:i:g:k:l:n:e:o:u:cqvpwth" opt; do
  case $opt in
    m) RASPBERRY_MODEL="$OPTARG"
    ;;
    r) LEDE_RELEASE="$OPTARG"
    ;;
    d) WORKING_DIR="$OPTARG"
    ;;
    a) MODULES_LIST="$OPTARG"
    ;;
    b) MODULES_DESTINATION="$OPTARG"
    ;;
    s) INITIAL_SCRIPT_PATH="$OPTARG"
    ;;
    i) INCLUDE_INITIAL_FILE="$OPTARG"
    ;;
    g) RUN_COMMAND_AFTER_MOUNT="$OPTARG"
    ;;
    k) LEDE_BOOT_PART_SIZE="$OPTARG"
    ;;
    l) LEDE_ROOT_PART_SIZE="$OPTARG"
    ;;
    n) BOOT_PART_LABEL="$OPTARG"
    ;;
    e) ROOT_PART_LABEL="$OPTARG"
    ;;
    o) LEDE_OS_NAME="$OPTARG"
    ;;
    u) UPGRADE_PARTITIONS="$OPTARG"
    ;;
    c) RUN_INITIAL_SCRIPT_ONCE=T
    ;;
    q) QUIET=T
    ;;
    v) VERBOSE=T
    ;;
    p) PAUSE_AFTER_MOUNT=T
    ;;
    w) DONT_GENERATE_FILES=T
    ;;
    t) DELETE_TEMP_FILES=N
    ;;
    h) HELP=T
    ;;
    \?) echo "Invalid option -$OPTARG" >&2; BAD_PARAMS=T
    ;;
  esac
done

if [ "$HELP" == "T" ]; then
  echo "
Usage:

lede2rpi.sh -m RASPBERRY_MODEL -r LEDE_RELEASE [OPTIONS]

OPTIONS:

-m RASPBERRY_MODEL
   RASPBERRY_MODEL=Pi|Pi2|Pi3, mandatory parameter

-r LEDE_RELEASE
   LEDE_RELEASE=snapshot|17.01.0|17.01.1|future_release_name, mandatory parameter

-d WORKING_DIR
   WORKING_DIR=<working_directory_path>, optional parameter, default=/tmp/
   Directory to store temporary and final files.

-p
   optional parameter
   Pause after boot and root partitions mount. You can add/modify files on both partitions in /media/$USER/[MOUNT_NAME] directories.

-a MODULES_LIST
   MODULES_LIST='module1 module2 ...', optional parameter
   List of modules to download and copy to root image into MODULES_DESTINATION directory

-b MODULES_DESTINATION
   MODULES_DESTINATION=<ipk_directory_path>, optional parameter, default=/root/ipk/
   Directory on LEDE root partition to copy downloaded modules from MODULES_LIST

-s INITIAL_SCRIPT_PATH
   INITIAL_SCRIPT_PATH=<initial_script_path>, optional parameter, default=none
   Path to store initial configuration script on LEDE root partition. Example: /root/init_config.sh

-i INCLUDE_INITIAL_FILE
   MODULES_LIST=<include_initial_script_path>, optional parameter
   Path to local script, to be included in initial configuration script INITIAL_SCRIPT_PATH.

-g RUN_COMMAND_AFTER_MOUNT
   RUN_COMMAND_AFTER_MOUNT=<command_to_run>, optional parameter
   Command to run after boot and root partitions mount.
   The command will receive two parameters: boot and root partitions mount directory.

-c
   optional parameter, default=no autorun initial script
   Run initial script INITIAL_SCRIPT_PATH once. Path to initial script will be added do /etc/rc.local and removed after first run.

-k LEDE_BOOT_PART_SIZE
   LEDE_BOOT_PART_SIZE=<boot_partition_size_in_mb>, optional parameter, default=25
   LEDE boot partition size in MB.

-l LEDE_ROOT_PART_SIZE
   LEDE_ROOT_PART_SIZE=<root_partition_size_in_mb>, optional parameter, default=300
   LEDE root partition size in MB.

-n BOOT_PART_LABEL
   BOOT_PART_LABEL=<boot_partition_label>, optional parameter, default=LEDE_boot
   LEDE boot partition label.

-e ROOT_PART_LABEL
   ROOT_PART_LABEL=<root_partition_label>, optional parameter, default=LEDE_root
   LEDE root partition label.

-o LEDE_OS_NAME
   LEDE_OS_NAME=<lede_os_name>, optional parameter, default=LEDE
   LEDE os name in os.json

-q
   optional parameter, default=no quiet
   Quiet mode.

-v
   optional parameter, default=no verbose
   Verbose mode.

-u UPGRADE_PARTITIONS
   UPGRADE_PARTITIONS='BOOT=<RPi_boot_dev>:<local_boot_dir>,ROOT=<RPi_root_dev>:<local_root_dir>', optional parameter
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

-h
   Display help and exit.
"
  exit
fi

[ ! "${QUIET}" == "T" ] && echo "LEDE2RPi version ${PROGRAM_VERSION}, RPi model=${RASPBERRY_MODEL}, LEDE release=${LEDE_RELEASE}"

[ -z "${RASPBERRY_MODEL}" ] && echo "Model not specified" && BAD_PARAMS=T

[ -z "${LEDE_RELEASE}" ] && echo "LEDE release not specified" && BAD_PARAMS=T

[ "${BAD_PARAMS}" == "T" ] && print_usage "-m Pi|Pi2|Pi3 -r LEDE_RELEASE|snapshot [-d WORKING_DIR] [-p] [-v] [-q] [-w] [-t] [-a MODULES_LIST] [-b MODULES_DESTINATION] [-s INITIAL_SCRIPT_PATH] [-i INCLUDE_INITIAL_FILE] [-g RUN_COMMAND_AFTER_MOUNT] [-q] [-k LEDE_BOOT_PART_SIZE] [-l LEDE_ROOT_PART_SIZE] [-n BOOT_PART_LABEL] [-e ROOT_PART_LABEL] [-o LEDE_OS_NAME] [-u UPGRADE_PARTITIONS]" "-m Pi3 -r 17.01.1" "-m Pi2 -r 17.01.0" "-m Pi  -r snapshot" "-h # help"

case "${RASPBERRY_MODEL}" in
  "Pi")  LEDE_SUBTARGET="bcm2708"; RASPBERRY_MODELS="\"Pi Model\", \"Pi Compute Module\", \"Pi Zero\""; RASPBERRY_HEX_REVISIONS="2,3,4,5,6,7,8,9,d,e,f,10,11,12,13,14,19,0092" ;;
  "Pi2") LEDE_SUBTARGET="bcm2709"; RASPBERRY_MODELS="\"Pi 2\""; RASPBERRY_HEX_REVISIONS="1040,1041" ;;
  "Pi3") LEDE_SUBTARGET="bcm2710"; RASPBERRY_MODELS="\"Pi 3\""; RASPBERRY_HEX_REVISIONS="2082" ;;
  *) error_exit "Unrecognized model: ${RASPBERRY_MODEL}"
esac

[ "$LEDE_RELEASE" == "snapshot" ] && LEDE_DOWNLOAD_DIR="snapshots" || LEDE_DOWNLOAD_DIR="releases/${LEDE_RELEASE}"
LEDE_DOWNLOAD="https://downloads.lede-project.org/${LEDE_DOWNLOAD_DIR}/targets/brcm2708/${LEDE_SUBTARGET}"
LEDE_IMAGE_COMPR_EXT=".gz"
LEDE_IMAGE_MASK="lede.*${LEDE_SUBTARGET}.*\.img\\${LEDE_IMAGE_COMPR_EXT}"
BLOCK_DEVICE_BOOT="/dev/dm-0"
BLOCK_DEVICE_ROOT="/dev/dm-1"
WORKING_SUB_DIR="${WORKING_DIR}/lede2R"`echo ${RASPBERRY_MODEL} | tr -d '[:space:]'`"_${LEDE_RELEASE}"
DESTINATION_DIR="${WORKING_SUB_DIR}/LEDE"
NOOBS_BOOT_IMAGE="${DESTINATION_DIR}/${BOOT_PART_LABEL}.tar"
NOOBS_ROOT_IMAGE="${DESTINATION_DIR}/${ROOT_PART_LABEL}.tar"
LEDE_HTML="lede.html"
LEDE_INIT_TMP_FILE="${WORKING_SUB_DIR}/lede_init.sh"
MODULES_DOWNLOAD_DIR="${WORKING_SUB_DIR}/ipk"
LEDE_KERNEL_IMAGE="kernel*.img"
LEDE_VERSION_FILE="usr/lib/os-release"
LEDE_KERNEL_VER_DEFAULT="4.5"
LEDE_REPO_COFIG="/etc/opkg/distfeeds.conf"
UPGRADE_BACKUP_DIR="${WORKING_SUB_DIR}/backup"
NOOBS_PARTITIONS_CONFIG_FILE="partitions.json"
NOOBS_OS_CONFIG_FILE="os.json"
NOOBS_ICON_FILE="${LEDE_OS_NAME}.png"
NOOBS_PARTITION_SETUP_FILE="partition_setup.sh"

[ "$DEBUG" == "T" ] && print_var_name_value DEBUG red bold

if [ "$VERBOSE" == "T" ]; then
  WGET_OPTS=""
  KPARTX_OPTS="v"
  GZIP_OPTS="v"
  STDOUT="/dev/stdout"
  QUIET=N
  print_var_name_value_verbose DESTINATION_DIR
  print_var_name_value_verbose LEDE_IMAGE_MASK
  print_var_name_value_verbose RASPBERRY_MODEL
  print_var_name_value_verbose RASPBERRY_MODELS
  print_var_name_value_verbose LEDE_SUBTARGET
  print_var_name_value_verbose LEDE_RELEASE
  print_var_name_value_verbose LEDE_DOWNLOAD
  print_var_name_value_verbose UPGRADE_PARTITIONS
fi

if [ ! -z "$UPGRADE_PARTITIONS" ]; then
  UPGRADE_BOOT_CONFIG=`echo "$UPGRADE_PARTITIONS" | cut -d, -f1`
  [ "${UPGRADE_BOOT_CONFIG:0:5}" != "BOOT=" ] && error_exit "Missing 'BOOT=' in upgrade config: ${UPGRADE_PARTITIONS}"

  UPGRADE_RPI_DEV_BOOT=`echo ${UPGRADE_BOOT_CONFIG:5} | cut -d\: -f1`
  print_var_name_value_verbose UPGRADE_RPI_DEV_BOOT
  [ -z "$UPGRADE_RPI_DEV_BOOT" ] && error_exit "Missing RPi device in upgrade BOOT config: ${UPGRADE_BOOT_CONFIG:5}"

  UPGRADE_DIR_BOOT=`echo ${UPGRADE_BOOT_CONFIG:5} | cut -d\: -f2`
  print_var_name_value_verbose UPGRADE_DIR_BOOT
  [ -z "$UPGRADE_DIR_BOOT" ] && error_exit "Missing local dir in upgrade BOOT config: ${UPGRADE_BOOT_CONFIG:5}"
  [ ! -d "$UPGRADE_DIR_BOOT" ] && error_exit "Upgrade BOOT config: ${UPGRADE_DIR_BOOT} is not a directory"

  UPGRADE_ROOT_CONFIG=`echo "$UPGRADE_PARTITIONS" | cut -d, -f2`
  [ "${UPGRADE_ROOT_CONFIG:0:5}" != "ROOT=" ] && error_exit "Missing 'ROOT=' in upgrade config: ${UPGRADE_PARTITIONS}"

  UPGRADE_RPI_DEV_ROOT=`echo ${UPGRADE_ROOT_CONFIG:5} | cut -d\: -f1`
  print_var_name_value_verbose UPGRADE_RPI_DEV_ROOT
  [ -z "$UPGRADE_RPI_DEV_ROOT" ] && error_exit "Missing RPi device in upgrade ROOT config: ${UPGRADE_ROOT_CONFIG:5}"

  UPGRADE_DIR_ROOT=`echo ${UPGRADE_ROOT_CONFIG:5} | cut -d\: -f2`
  print_var_name_value_verbose UPGRADE_DIR_ROOT
  [ -z "$UPGRADE_DIR_ROOT" ] && error_exit "Missing local dir in upgrade ROOT config: ${UPGRADE_ROOT_CONFIG:5}"
  [ ! -d "$UPGRADE_DIR_ROOT" ] && error_exit "Upgrade ROOT config: ${UPGRADE_DIR_ROOT} is not a directory"

  ANSWER=`input_line "Are you sure to delete all files from $UPGRADE_DIR_BOOT and $UPGRADE_DIR_ROOT and upgrade LEDE instalation? Enter 'yes': "`
  [ "$ANSWER" != "yes" ] && error_exit "User abort"
fi

unmount_image() {
  if [ -d "$2" ]; then
    print_info "Unmounting $1 -> $2\n"
    while lsof -p ^$$ "$2" ; do
      pause "Above processes are blocking directory $2. Release the lock and press ENTER."
    done

    udisksctl unmount --block-device "$1" > "${STDOUT}"
    sleep 1
  fi
}

unmount_images() {
  #cd "${WORKING_DIR}"
  sync

  unmount_image "${BLOCK_DEVICE_ROOT}" "${ROOT_PARTITION_DIR}"
  unmount_image "${BLOCK_DEVICE_BOOT}" "${BOOT_PARTITION_DIR}"

  if [ ! -z "${LEDE_IMAGE_DECOMPR}"  ]; then
    if sudo kpartx -l${KPARTX_OPTS} "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}" | grep -vq "loop deleted"; then
      print_info "Deleting device maps from ${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}\n"
      sudo kpartx -d${KPARTX_OPTS} "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}" > "${STDOUT}"
    fi
  fi
}

clean_and_exit() {
  if [ -z "${CLEANED}" ]; then
    unmount_images
    CLEANED=T
    error_exit "$1"
  fi
}

trap 'clean_and_exit "ERROR COMMAND: $BASH_COMMAND in line $LINENO"' $TRAP_SIGNALS

#cd "${WORKING_DIR}"
mkdir -p "${WORKING_SUB_DIR}"

# debug
[ "$DEBUG" != "T" ] && wget -${WGET_OPTS}O "${WORKING_SUB_DIR}/${LEDE_HTML}" "${LEDE_DOWNLOAD}"

LEDE_IMAGE_COMPR=`grep -o '"'${LEDE_IMAGE_MASK}'"' "${WORKING_SUB_DIR}/${LEDE_HTML}" | grep -o "${LEDE_IMAGE_MASK}"`

[ -z "${LEDE_IMAGE_COMPR}" ] && clean_and_exit "Can't get LEDE image name"
print_var_name_value_verbose LEDE_IMAGE_COMPR

LEDE_RELEASE_DATE=`grep -o '<td class="d">.*</td>' "${WORKING_SUB_DIR}/${LEDE_HTML}" | head -n1`
LEDE_RELEASE_DATE=`date -d"${LEDE_RELEASE_DATE:14: -5}" +%Y-%m-%d`
print_var_name_value_verbose LEDE_RELEASE_DATE

# debug
[ "$DEBUG" != "T" ] && wget -${WGET_OPTS}O "${WORKING_SUB_DIR}/${LEDE_IMAGE_COMPR}" "${LEDE_DOWNLOAD}/${LEDE_IMAGE_COMPR}"

# debug
[ "$DEBUG" != "T" ] && gzip -d${GZIP_OPTS} "${WORKING_SUB_DIR}/${LEDE_IMAGE_COMPR}"

LEDE_IMAGE_DECOMPR=`basename "${LEDE_IMAGE_COMPR}" "${LEDE_IMAGE_COMPR_EXT}"`

[ -z "${LEDE_IMAGE_DECOMPR}" ] && clean_and_exit "Can't unpack LEDE image"

if [ "$VERBOSE" == "T" ]; then
  print_var_name_value_verbose LEDE_IMAGE_DECOMPR
  parted "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}" print
  print_var_name_value_verbose LEDE_BOOT_PART_SIZE
  print_var_name_value_verbose LEDE_ROOT_PART_SIZE
fi

print_info "Create device maps from ${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}\n"
sudo kpartx -sa${KPARTX_OPTS} "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}"
sleep 1

BOOT_UUID=`udisksctl mount --block-device "${BLOCK_DEVICE_BOOT}" | grep -o "${MEDIA_USER_DIR}/.*"`
BOOT_UUID=`basename "${BOOT_UUID}" .`
[ -z "${BOOT_UUID}" ] && clean_and_exit "Can't evaluate BOOT_UUID name"
print_var_name_value_verbose BOOT_UUID
BOOT_PARTITION_DIR="${MEDIA_USER_DIR}/${BOOT_UUID}"

ROOT_UUID=`udisksctl mount --block-device "${BLOCK_DEVICE_ROOT}" | grep -o "${MEDIA_USER_DIR}/.*"`
ROOT_UUID=`basename "${ROOT_UUID}" .`
[ -z "${ROOT_UUID}" ] && clean_and_exit "Can't evaluate ROOT_UUID name"
print_var_name_value_verbose ROOT_UUID
ROOT_PARTITION_DIR="${MEDIA_USER_DIR}/${ROOT_UUID}"

#cd "${BOOT_PARTITION_DIR}"

LEDE_KERNEL_VER=`grep -ao "Linux version [0-9]\.[0-9]\{1,2\}\.[0-9]\{1,3\}" "${BOOT_PARTITION_DIR}"/${LEDE_KERNEL_IMAGE} | head -n1`
LEDE_KERNEL_VER="${LEDE_KERNEL_VER:14}"
[ -z "${LEDE_KERNEL_VER}" ] && LEDE_KERNEL_VER="${LEDE_KERNEL_VER_DEFAULT}"
print_var_name_value_verbose LEDE_KERNEL_VER

cat <<EOF > "${LEDE_INIT_TMP_FILE}"
#!/bin/sh
EOF

if [ ! -z "$MODULES_LIST" ]; then
  print_info "Downloading modules: $MODULES_LIST into $MODULES_DESTINATION directory on LEDE root partition\n"

  SEPARATOR=""
  MODULES_PATTERN=""
  for MODULE in $MODULES_LIST; do
    MODULES_PATTERN=${MODULES_PATTERN}${SEPARATOR}'(?<=<a href=")'${MODULE}'_.*?\.ipk(?=">)'
    SEPARATOR="|"
    echo 'opkg install '${MODULES_DESTINATION}'/'${MODULE}'*.ipk' >> "${LEDE_INIT_TMP_FILE}"
  done
  echo '# rm '${MODULES_DESTINATION}'/*.ipk' >> "${LEDE_INIT_TMP_FILE}"
  echo '# rmdir '${MODULES_DESTINATION} >> "${LEDE_INIT_TMP_FILE}"
  [ "$DEBUG" == "T" ] && print_var_name_value_verbose MODULES_PATTERN

  mkdir -p "${MODULES_DOWNLOAD_DIR}"
  rm -f "${MODULES_DOWNLOAD_DIR}"/* #2>/dev/null

  for REPO_ADDR in $(grep -o 'http://.*' "${ROOT_PARTITION_DIR}${LEDE_REPO_COFIG}"); do
    for PACKAGE_NAME in $(wget -${WGET_OPTS}O - "${REPO_ADDR}" | grep -oP "${MODULES_PATTERN}"); do
      [ "$VERBOSE" == "T" ] && print_info "Downloading ${REPO_ADDR}/${PACKAGE_NAME}\n"
      wget -${WGET_OPTS}P "${MODULES_DOWNLOAD_DIR}" "${REPO_ADDR}/${PACKAGE_NAME}"
    done
  done
  sudo cp -R "${MODULES_DOWNLOAD_DIR}/." "${ROOT_PARTITION_DIR}/${MODULES_DESTINATION}"
fi

if [ ! -z "${RUN_INITIAL_SCRIPT_ONCE}" ]; then
  print_info "Sheduling one run of initial script using LEDE ${RC_LOCAL}\n"

  echo 'sed -i "/#lede2rpi_delete/d" '${RC_LOCAL} >> "${LEDE_INIT_TMP_FILE}"

  sudo sed -i "/exit 0/i ${INITIAL_SCRIPT_PATH} #lede2rpi_delete" "${ROOT_PARTITION_DIR}${RC_LOCAL}"
fi

if [ ! -z "${INCLUDE_INITIAL_FILE}" ]; then
  print_info "Including local initial file ${INCLUDE_INITIAL_FILE}\n"

  cat "${INCLUDE_INITIAL_FILE}" >> "${LEDE_INIT_TMP_FILE}"
fi

if [ ! -z "$INITIAL_SCRIPT_PATH" ]; then
  print_info "Creating initial script ${INITIAL_SCRIPT_PATH} on LEDE root partition\n"

  sudo cp "${LEDE_INIT_TMP_FILE}" "${ROOT_PARTITION_DIR}/${INITIAL_SCRIPT_PATH}"
  sudo chmod u+x "${ROOT_PARTITION_DIR}/$INITIAL_SCRIPT_PATH"
fi

if [ ! -z "$RUN_COMMAND_AFTER_MOUNT" ]; then
  print_info "Executing user command: ${RUN_COMMAND_AFTER_MOUNT}\n"
  $RUN_COMMAND_AFTER_MOUNT "${BOOT_PARTITION_DIR}" "${ROOT_PARTITION_DIR}"
  print_info "User command finished\n"
fi

[ "$PAUSE_AFTER_MOUNT" == "T" ] && pause "Now you can modify files in boot (${BOOT_PARTITION_DIR}) and root (${ROOT_PARTITION_DIR}) partitions. Press ENTER when done."

if [ -z "$DONT_GENERATE_FILES" ]; then
  mkdir -p "${DESTINATION_DIR}"
  rm -f "${DESTINATION_DIR}"/* #2>/dev/null

  #cd "${BOOT_PARTITION_DIR}"

  tar -cpf "${NOOBS_BOOT_IMAGE}" -C "${BOOT_PARTITION_DIR}" . || clean_and_exit "tar boot image failed"
  BOOT_TAR_SIZE=`du -m "${NOOBS_BOOT_IMAGE}" | cut -f1` #ls "${NOOBS_BOOT_IMAGE}" -l --block-size=1MB
  print_var_name_value_verbose BOOT_TAR_SIZE
  print_info "xz compressing partition boot..."
  xz -9 -e "${NOOBS_BOOT_IMAGE}"
  print_info "done\n"

  #cd "${ROOT_PARTITION_DIR}"

  LEDE_VERSION_ID=$(get_param_from_file "${ROOT_PARTITION_DIR}/${LEDE_VERSION_FILE}" VERSION_ID)
  LEDE_BUILD_ID=$(get_param_from_file "${ROOT_PARTITION_DIR}/${LEDE_VERSION_FILE}" BUILD_ID)
  LEDE_VERSION="${LEDE_VERSION_ID} ${LEDE_BUILD_ID}"
  print_var_name_value_verbose LEDE_VERSION

  sudo tar -cpf "${NOOBS_ROOT_IMAGE}" -C "${ROOT_PARTITION_DIR}" . --exclude=proc/* --exclude=sys/* --exclude=dev/pts/* || clean_and_exit "tar root image failed"
  sudo chown ${USER}:${USER} "${NOOBS_ROOT_IMAGE}"
  ROOT_TAR_SIZE=`du -m "${NOOBS_ROOT_IMAGE}" | cut -f1`
  print_var_name_value_verbose ROOT_TAR_SIZE
  print_info "xz compressing partition root..."
  xz -9 -e "${NOOBS_ROOT_IMAGE}"
  print_info "done\n"

  ##################################################################### partition_setup.sh
  print_info "Creating ${NOOBS_PARTITION_SETUP_FILE}\n"
cat <<'EOF' > "${DESTINATION_DIR}/${NOOBS_PARTITION_SETUP_FILE}"
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

umount /tmp/1
umount /tmp/2
EOF
  ##################################################################### partitions.json
  print_info "Creating ${NOOBS_PARTITIONS_CONFIG_FILE}\n"
cat <<EOF > "${DESTINATION_DIR}/${NOOBS_PARTITIONS_CONFIG_FILE}"
{
  "partitions": [
    {
      "label": "${BOOT_PART_LABEL}",
      "filesystem_type": "FAT",
      "partition_size_nominal": ${LEDE_BOOT_PART_SIZE},
      "want_maximised": false,
      "uncompressed_tarball_size": ${BOOT_TAR_SIZE}
    },
    {
      "label": "${ROOT_PART_LABEL}",
      "filesystem_type": "ext4",
      "partition_size_nominal": ${LEDE_ROOT_PART_SIZE},
      "want_maximised": false,
      "mkfs_options": "-O ^huge_file",
      "uncompressed_tarball_size": ${ROOT_TAR_SIZE}
    }
  ]
}
EOF
  ##################################################################### os.json
  print_info "Creating ${NOOBS_OS_CONFIG_FILE}\n"
cat <<EOF > "${DESTINATION_DIR}/${NOOBS_OS_CONFIG_FILE}"
{
  "name": "${LEDE_OS_NAME}",
  "version": "${LEDE_VERSION}",
  "release_date": "${LEDE_RELEASE_DATE}",
  "kernel": "${LEDE_KERNEL_VER}",
  "description": "LEDE for the Raspberry ${RASPBERRY_MODEL}",
  "url": "${LEDE_DOWNLOAD}",
  "supported_hex_revisions": "${RASPBERRY_HEX_REVISIONS}",
  "supported_models": [
        ${RASPBERRY_MODELS}
  ],
  "feature_level": 0
}
EOF
  ##################################################################### LOGO: xxd -ps -c72 lede_40x40_source.png
  print_info "Creating ${NOOBS_ICON_FILE}\n"
xxd -r -ps <<'EOF' > "${DESTINATION_DIR}/${NOOBS_ICON_FILE}"
89504e470d0a1a0a0000000d4948445200000028000000280802000000039c2f3a0000028f4944415458c3ed58d1b59b300c75de610131022b9811c8085e01464846801160843042
18018f108fe03b02ef43c131c6a4f49df6d1d3565f80a57b2559929d9ca6691247c887384822c4c698038801f47d0fe05f4af57fe2bf9cf81bea992589f5317c2788e8bd67ace0be
07fa6b135648d64a80e187ebf50aa06d5b1fabaa2a1f4e4a59d7b531a6aa2aa796655951144551b05ad3343c94d8a4288acbe522a6a58ce3286561adb5d63290b5d657e08f449465
5996654a29b672942eacb66da769b2d64a297989a52c4b6b6d94583231a3ac8989e87ebf07561cfde3f198a6a96d5ba6671c260e70a2a91600d65b158cd56118984c2915289465c9
0ac33070c285104dd3f003ef42b205fd865808d1f73d3f28a5d6c42ee7c61887d3759ddb854de2f74244755d7302b7fcd35a33bd2be9dbede6ea23de4e4244aa3f10292513af7de2
76d05a73646ec97fde35b94eb39ccf67b711799ef3c73ccf5d4c5aeb344dd334edba8eabda77dae1b0c9bab81661b9f6e05776dc1f08ac4044524abfd394522e256e69d172413bdd
6e37a26c1cc7e937cb9f753ae190d3e9b0887158aabfe7483eec2270f27fc20030c60098dbf7fdc08e4fd39f2306a0b566c3d9780b8404097abb417be83fdcb403b0acac17d432fd
e0b3135868bb0bd0736d0fb153657dcfca21acbc7a7a208097feccbdbbb89c9b7386b0e486e0d45274d480f5f10a5dec8939f1ae95c448345f056668120244f150e6ed8440901144
3d0daeb720a227ee8bd90cc3a0b5664422e16f8a3b854a55ca427ef95ecd3151e0eac6694fc15b24ad3baa3a99d528e802be4dc6db693dde8306037ec89dccfb445bee623dbfb74a
6ddbb937c4f06c106250e4e8408c87b34e04a26c27b1985bf92b7f806059e67b265730ab7fc1b1b8735c7f0277345a2a632c143f0000000049454e44ae426082
EOF
  #####################################################################

  print_info "\nLEDE files for NOOBS are stored in ${DESTINATION_DIR} directory.\nNow you can copy directory LEDE to NOOBS/PINN SD card into /os folder\n\n"
fi

if [ ! -z "$UPGRADE_PARTITIONS" ]; then
  mkdir -p "${UPGRADE_BACKUP_DIR}" "${UPGRADE_BACKUP_DIR}/etc"

  print_info "Upgrading boot partition\n"
  cp "${UPGRADE_DIR_BOOT}/cmdline.txt" "${UPGRADE_BACKUP_DIR}"
  cp "${UPGRADE_DIR_BOOT}/os_config.json" "${UPGRADE_BACKUP_DIR}"
  sudo find "${UPGRADE_DIR_BOOT}" -mindepth 1 -delete

  sudo cp -a "${BOOT_PARTITION_DIR}/." "${UPGRADE_DIR_BOOT}"
  sudo sed "${UPGRADE_DIR_BOOT}/cmdline.txt" -i -e "s|root=/dev/[^ ]*|root=${UPGRADE_RPI_DEV_ROOT}|"
  sudo cp "${UPGRADE_BACKUP_DIR}/os_config.json" "${UPGRADE_DIR_BOOT}"

  print_info "Upgrading root partition\n"
  sudo cp -a "${UPGRADE_DIR_ROOT}/etc" "${UPGRADE_BACKUP_DIR}"
  sudo find "${UPGRADE_DIR_ROOT}" -mindepth 1 -delete

  sudo cp -a "${ROOT_PARTITION_DIR}/." "${UPGRADE_DIR_ROOT}"
  sudo sed "${UPGRADE_DIR_ROOT}/etc/fstab" -i -e "s|^.* / |${UPGRADE_RPI_DEV_ROOT}  / |"
  sudo sed "${UPGRADE_DIR_ROOT}/etc/fstab" -i -e "s|^.* /boot |${UPGRADE_RPI_DEV_BOOT}  /boot |"

  print_info "\nLEDE instalation in ${UPGRADE_DIR_BOOT} and ${UPGRADE_DIR_ROOT} upgraded.\nBackup files you can find in directory ${UPGRADE_BACKUP_DIR}\n\n"
fi

trap - $TRAP_SIGNALS

unmount_images

if [ "$DELETE_TEMP_FILES" == "T" ]; then
  print_info "Removing temporary files from ${WORKING_SUB_DIR}\n"
  rm "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}"
  rm "${WORKING_SUB_DIR}/${LEDE_HTML}"
  if [ ! -z "$MODULES_LIST" ]; then
    rm -f "${MODULES_DOWNLOAD_DIR}"/* #2>/dev/null
    rmdir "${MODULES_DOWNLOAD_DIR}"
  fi
  rm "${LEDE_INIT_TMP_FILE}"
fi

