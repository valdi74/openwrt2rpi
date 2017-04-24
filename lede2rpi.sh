#!/bin/bash

. ${0%/*}/common_defs.sh

#defaults
PROGRAM_VERSION="1.01"
WORKING_DIR="${TMP_DIR}"
LEDE_BOOT_PART_SIZE=25
LEDE_ROOT_PART_SIZE=300
LEDE_OS_NAME="LEDE"
BOOT_PART_LABEL="LEDE_boot"
ROOT_PART_LABEL="LEDE_root"
MODULES_DESTINATION="/root/ipk/"
PAUSE_AFTER_MOUNT=N
RC_LOCAL="/etc/rc.local"

DEBUG=N
#test
#./lede2rpi.sh -m Pi3 -r 17.01.1 -p -s /root/init_config.sh -i ~/tmp/my_lede_init.sh -b /root/ipk -a "kmod-usb2 librt libusb-1.0" -k 26 -l 302 -n LEDE_boot -e LEDE_root -o LEDE

echo "LEDE2RPi version ${PROGRAM_VERSION}"

BAD_PARAMS=N
while getopts ":m:r:d:a:b:s:i:k:l:n:e:o:p" opt; do
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
    r) RUN_INITIAL_SCRIPT_ONCE=T
    ;;
    p) PAUSE_AFTER_MOUNT=T
    ;;
    \?) echo "Invalid option -$OPTARG" >&2; BAD_PARAMS=T
    ;;
  esac
done

[ -z "$RASPBERRY_MODEL" ] && echo "Model not specified" && BAD_PARAMS=T

[ -z "$LEDE_RELEASE" ] && echo "LEDE release not specified" && BAD_PARAMS=T

[ "$BAD_PARAMS" == "T" ] && print_usage "-m Pi|Pi2|Pi3 -r LEDE_RELEASE|snapshot [-d WORKING_DIR] [-p]" "-m Pi3 -r 17.01.1" "-m Pi2 -r 17.01.0" "-m Pi  -r 17.01.1"

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

[ "$DEBUG" == "T" ] && print_var_name_value DEBUG red bold

cd "${WORKING_DIR}"
mkdir -p "${DESTINATION_DIR}"
rm "${DESTINATION_DIR}"/* 2>/dev/null

print_var_name_value DESTINATION_DIR
print_var_name_value LEDE_IMAGE_MASK
print_var_name_value RASPBERRY_MODEL
print_var_name_value RASPBERRY_MODELS
print_var_name_value LEDE_SUBTARGET
print_var_name_value LEDE_RELEASE
print_var_name_value LEDE_DOWNLOAD

# debug
[ "$DEBUG" != "T" ] && wget -O "${WORKING_SUB_DIR}/${LEDE_HTML}" "${LEDE_DOWNLOAD}"

LEDE_IMAGE_COMPR=`grep -o '"'${LEDE_IMAGE_MASK}'"' "${WORKING_SUB_DIR}/${LEDE_HTML}" | grep -o "${LEDE_IMAGE_MASK}"`

[ -z "${LEDE_IMAGE_COMPR}" ] && error_exit "Can't get LEDE image name"
print_var_name_value LEDE_IMAGE_COMPR

LEDE_RELEASE_DATE=`grep -o '<td class="d">.*</td>' "${WORKING_SUB_DIR}/${LEDE_HTML}" | head -n1`
LEDE_RELEASE_DATE=`date -d"${LEDE_RELEASE_DATE:14: -5}" +%Y-%m-%d`
print_var_name_value LEDE_RELEASE_DATE

# debug
[ "$DEBUG" != "T" ] && wget -O "${WORKING_SUB_DIR}/${LEDE_IMAGE_COMPR}" "${LEDE_DOWNLOAD}/${LEDE_IMAGE_COMPR}"

# debug
[ "$DEBUG" != "T" ] && gzip -dv "${WORKING_SUB_DIR}/${LEDE_IMAGE_COMPR}"

LEDE_IMAGE_DECOMPR=`basename "${LEDE_IMAGE_COMPR}" "${LEDE_IMAGE_COMPR_EXT}"`

[ -z "${LEDE_IMAGE_DECOMPR}" ] && error_exit "Can't unpack LEDE image"
print_var_name_value LEDE_IMAGE_DECOMPR

parted "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}" print
print_var_name_value LEDE_BOOT_PART_SIZE
print_var_name_value LEDE_ROOT_PART_SIZE

sudo kpartx -sav "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}"
sleep 1

BOOT_UUID=`udisksctl mount --block-device "${BLOCK_DEVICE_BOOT}" | grep -o "${MEDIA_USER_DIR}/.*"`
BOOT_UUID=`basename "${BOOT_UUID}" .`
[ -z "${BOOT_UUID}" ] && error_exit "Can't evaluate BOOT_UUID name"
print_var_name_value BOOT_UUID

ROOT_UUID=`udisksctl mount --block-device "${BLOCK_DEVICE_ROOT}" | grep -o "${MEDIA_USER_DIR}/.*"`
ROOT_UUID=`basename "${ROOT_UUID}" .`
[ -z "${ROOT_UUID}" ] && error_exit "Can't evaluate ROOT_UUID name"
print_var_name_value ROOT_UUID

cd "${MEDIA_USER_DIR}/${BOOT_UUID}"

LEDE_KERNEL_VER=`grep -ao "Linux version [0-9]\.[0-9]\{1,2\}\.[0-9]\{1,3\}" ${LEDE_KERNEL_IMAGE} | head -n1`
LEDE_KERNEL_VER="${LEDE_KERNEL_VER:14}"
[ -z "${LEDE_KERNEL_VER}" ] && LEDE_KERNEL_VER="${LEDE_KERNEL_VER_DEFAULT}"
print_var_name_value LEDE_KERNEL_VER

cat <<EOF > "${LEDE_INIT_TMP_FILE}"
#!/bin/sh
#cd "$MODULES_DESTINATION"
EOF

if [ ! -z "$MODULES_LIST" ]; then
  echo "Downloading modules: $MODULES_LIST into $MODULES_DESTINATION directory on LEDE root partition"

  SEPARATOR=""
  MODULES_PATTERN=""
  for MODULE in $MODULES_LIST; do
    MODULES_PATTERN=${MODULES_PATTERN}${SEPARATOR}'(?<=<a href=")'${MODULE}'_.*?\.ipk(?=">)'
    SEPARATOR="|"
    echo 'opkg install "'${MODULES_DESTINATION}'/'${MODULE}'*.ipk"' >> "${LEDE_INIT_TMP_FILE}"
  done
  [ "$DEBUG" == "T" ] && print_var_name_value MODULES_PATTERN

  mkdir -p "${MODULES_DOWNLOAD_DIR}"
  rm "${MODULES_DOWNLOAD_DIR}"/* 2>/dev/null

  for REPO_ADDR in $(grep -o 'http://.*' "${MEDIA_USER_DIR}/${ROOT_UUID}${LEDE_REPO_COFIG}"); do
    for PACKAGE_NAME in $(wget -qO - "${REPO_ADDR}" | grep -oP "${MODULES_PATTERN}"); do
      echo "Downloading ${REPO_ADDR}/${PACKAGE_NAME}"
      wget -qP "${MODULES_DOWNLOAD_DIR}" "${REPO_ADDR}/${PACKAGE_NAME}"
    done
  done
  sudo cp -R "${MODULES_DOWNLOAD_DIR}/." "${MEDIA_USER_DIR}/${ROOT_UUID}/${MODULES_DESTINATION}"
fi

[ ! -z "${INCLUDE_INITIAL_FILE}" ] && cat "${INCLUDE_INITIAL_FILE}" >> "${LEDE_INIT_TMP_FILE}"

if [ ! -z "${RUN_INITIAL_SCRIPT_ONCE}" ]; then
  echo 'sed -i "/#lede2rpi_delete/d" '${RC_LOCAL} >> "${LEDE_INIT_TMP_FILE}"

  sed -i "/exit 0/i \
${INCLUDE_INITIAL_FILE} & #lede2rpi_delete\
" "${MEDIA_USER_DIR}/${ROOT_UUID}${RC_LOCAL}"
fi

if [ ! -z "$INITIAL_SCRIPT_PATH" ]; then
  echo "Creating initial script ${INITIAL_SCRIPT_PATH} on LEDE root partition"
  sudo cp "${LEDE_INIT_TMP_FILE}" "${MEDIA_USER_DIR}/${ROOT_UUID}/${INITIAL_SCRIPT_PATH}"
  sudo chmod u+x "${MEDIA_USER_DIR}/${ROOT_UUID}/$INITIAL_SCRIPT_PATH"
fi

[ "$PAUSE_AFTER_MOUNT" == "T" ] && pause "Now you can modify files in boot (${MEDIA_USER_DIR}/${BOOT_UUID}) and root (${MEDIA_USER_DIR}/${ROOT_UUID}) partitions. Press ENTER when done."

tar -cpf "${NOOBS_BOOT_IMAGE}" .
#ls "${NOOBS_BOOT_IMAGE}" -l --block-size=1MB
BOOT_TAR_SIZE=`du -m "${NOOBS_BOOT_IMAGE}" | cut -f1`
print_var_name_value BOOT_TAR_SIZE
echo -n "xz boot..."
xz -9 -e "${NOOBS_BOOT_IMAGE}"
echo ok

cd "${MEDIA_USER_DIR}/${ROOT_UUID}"

LEDE_VERSION_ID=$(get_param_from_file ${LEDE_VERSION_FILE} VERSION_ID)
LEDE_BUILD_ID=$(get_param_from_file ${LEDE_VERSION_FILE} BUILD_ID)
LEDE_VERSION="${LEDE_VERSION_ID} ${LEDE_BUILD_ID}"
print_var_name_value LEDE_VERSION

sudo tar -cpf "${NOOBS_ROOT_IMAGE}" . --exclude=proc/* --exclude=sys/* --exclude=dev/pts/*
sudo chown ${USER}:${USER} "${NOOBS_ROOT_IMAGE}"
#ls "${NOOBS_ROOT_IMAGE}" -l --block-size=1MB
ROOT_TAR_SIZE=`du -m "${NOOBS_ROOT_IMAGE}" | cut -f1`
print_var_name_value ROOT_TAR_SIZE
echo -n "xz root..."
xz -9 -e "${NOOBS_ROOT_IMAGE}"
echo ok

cd "${DESTINATION_DIR}"

udisksctl unmount --block-device "${BLOCK_DEVICE_ROOT}"
sleep 1
udisksctl unmount --block-device "${BLOCK_DEVICE_BOOT}"
sleep 1

sudo kpartx -dv "${WORKING_SUB_DIR}/${LEDE_IMAGE_DECOMPR}"

#####################################################################
cat <<EOF > partition_setup.sh
#!/bin/sh

set -ex

if [ -z "\$part1" ] || [ -z "\$part2" ]; then
  printf "Error: missing environment variable part1 or part2\n" 1>&2
  exit 1
fi

mkdir -p /tmp/1 /tmp/2

mount "\$part1" /tmp/1
mount "\$part2" /tmp/2

sed /tmp/1/cmdline.txt -i -e "s|root=/dev/[^ ]*|root=\${part2}|"
sed /tmp/2/etc/fstab -i -e "s|^.* / |\${part2}  / |"
sed /tmp/2/etc/fstab -i -e "s|^.* /boot |\${part1}  /boot |"

umount /tmp/1
umount /tmp/2
EOF
##################################################################### partitions.json
cat <<EOF > partitions.json
{
  "partitions": [
    {
      "label": "${BOOT_PART_LABEL}",
      "filesystem_type": "FAT",
      "partition_size_nominal": $LEDE_BOOT_PART_SIZE,
      "want_maximised": false,
      "uncompressed_tarball_size": $BOOT_TAR_SIZE
    },
    {
      "label": "${ROOT_PART_LABEL}",
      "filesystem_type": "ext4",
      "partition_size_nominal": $LEDE_ROOT_PART_SIZE,
      "want_maximised": false,
      "mkfs_options": "-O ^huge_file",
      "uncompressed_tarball_size": $ROOT_TAR_SIZE
    }
  ]
}
EOF
##################################################################### os.json
cat <<EOF > os.json
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
xxd -r -ps <<EOF >${LEDE_OS_NAME}.png
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

echo "Done. LEDE files for NOOBS stored in ${DESTINATION_DIR} directory"
echo "Now you can copy directory noobs_lede to NOOBS SD card into /os folder"

