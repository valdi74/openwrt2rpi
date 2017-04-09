#!/bin/bash

# 2do:

. ${0%/*}/common_defs.sh

[ -z "$2" ] || [ -n "$3" ] && print_usage "Pi|Pi2|Pi3 LEDE_RELEASE|snapshot" "Pi3 snapshot" "Pi2 17.01.0" "Pi  17.01.1"

DEBUG=N
RASPBERRY_MODEL="$1" # "Pi" or "Pi2" or "Pi3"
LEDE_RELEASE="$2"    # "snapshot" or "17.01.0"

LEDE_BOOT_PART_SIZE=25
LEDE_ROOT_PART_SIZE=300
LEDE_OS_NAME="LEDE"

case "${RASPBERRY_MODEL}" in
  "Pi")   LEDE_SUBTARGET="bcm2708"; RASPBERRY_MODELS="\"Pi Model\", \"Pi Compute Module\", \"Pi Zero\""; RASPBERRY_HEX_REVISIONS="2,3,4,5,6,7,8,9,d,e,f,10,11,12,13,14,19,0092" ;;
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
WORK_DIR="${TMP_DIR}/lede2R"`echo ${RASPBERRY_MODEL} | tr -d '[:space:]'`"_${LEDE_RELEASE}"
DESTINATION_DIR="${WORK_DIR}/noobs_lede"
NOOBS_BOOT_IMAGE="${DESTINATION_DIR}/boot.tar"
NOOBS_ROOT_IMAGE="${DESTINATION_DIR}/root.tar"
LEDE_HTML="lede.html"
LEDE_KERNEL_IMAGE="kernel*.img"
LEDE_VERSION_FILE="usr/lib/os-release"
LEDE_KERNEL_VER_DEFAULT="4.5"

[ "$DEBUG" == "T" ] && print_var_name_value DEBUG red bold

cd "${TMP_DIR}"
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
[ "$DEBUG" != "T" ] && wget -O "${WORK_DIR}/${LEDE_HTML}" "${LEDE_DOWNLOAD}"

LEDE_IMAGE_COMPR=`grep -o '"'${LEDE_IMAGE_MASK}'"' "${WORK_DIR}/${LEDE_HTML}" | grep -o "${LEDE_IMAGE_MASK}"`

[ -z "${LEDE_IMAGE_COMPR}" ] && error_exit "Can't get LEDE image name"
print_var_name_value LEDE_IMAGE_COMPR

LEDE_RELEASE_DATE=`grep -o '<td class="d">.*</td>' "${WORK_DIR}/${LEDE_HTML}" | head -n1`
LEDE_RELEASE_DATE=`date -d"${LEDE_RELEASE_DATE:14: -5}" +%Y-%m-%d`
print_var_name_value LEDE_RELEASE_DATE

# debug
[ "$DEBUG" != "T" ] && wget -O "${WORK_DIR}/${LEDE_IMAGE_COMPR}" "${LEDE_DOWNLOAD}/${LEDE_IMAGE_COMPR}"

# debug
[ "$DEBUG" != "T" ] && gzip -dv "${WORK_DIR}/${LEDE_IMAGE_COMPR}"

LEDE_IMAGE_DECOMPR=`basename "${LEDE_IMAGE_COMPR}" "${LEDE_IMAGE_COMPR_EXT}"`

[ -z "${LEDE_IMAGE_DECOMPR}" ] && error_exit "Can't unpack LEDE image"
print_var_name_value LEDE_IMAGE_DECOMPR

parted "${WORK_DIR}/${LEDE_IMAGE_DECOMPR}" print
print_var_name_value LEDE_BOOT_PART_SIZE
print_var_name_value LEDE_ROOT_PART_SIZE

sudo kpartx -av "${WORK_DIR}/${LEDE_IMAGE_DECOMPR}"
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

sudo kpartx -dv "${WORK_DIR}/${LEDE_IMAGE_DECOMPR}"

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
      "label": "boot",
      "filesystem_type": "FAT",
      "partition_size_nominal": $LEDE_BOOT_PART_SIZE,
      "want_maximised": false,
      "uncompressed_tarball_size": $BOOT_TAR_SIZE
    },
    {
      "label": "root",
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
##################################################################### LOGO: xxd -ps -c70 lede_40x40_source.png
xxd -r -ps <<EOF >${LEDE_OS_NAME}.png
89504e470d0a1a0a0000000d4948445200000028000000280802000000039c2f3a000000d74944415458c3ed54410ec4200884a6ff565ece1e485ca280b5d1bd2c73aa032356
1c001289c426a05e303322d65a3529cb8e1494528848a23ac19368e61e63a514002022f9e82a494857d56942b6023a3f823ee9f8df5db4d6cacc814a33cc6cde59e20fecd43a
6f3e018f8c93e75bc9fb1498e6630b011fab64dbebc4353e71cefec2e3d8897a2ca3000010714c92683780da00b1f745f454ef7b3c76d1643cd5e6ab5e9d88d76fca8caabec7
412f1bdff44b3d36ceea796eead777aa53762222d31ac77dfc10f7f4a578d1985f552512894422f1c507816a883e7db1b30f0000000049454e44ae426082
EOF
#####################################################################

echo "Done. LEDE files for NOOBS stored in ${DESTINATION_DIR} directory"

