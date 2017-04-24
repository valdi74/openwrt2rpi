# lede2rpi
Linux shell script for downloading and converting LEDE img to Raspberry Pi NOOBS/PINN installer format

## Usage:
```
$ lede2rpi.sh -m RPI_MODEL -r LEDE_RELEASE [OPTIONS]

OPTIONS:

-m RASPBERRY_MODEL
   RASPBERRY_MODEL=Pi|Pi2|Pi3, mandatory parameter

-r LEDE_RELEASE
   LEDE_RELEASE=snapshot|17.01.0|17.01.0|future_release_name, mandatory parameter

-d WORKING_DIR
   WORKING_DIR=<working_directory_path>, optional parameter, default=/tmp/
   Directory to store temporary and final files.

-p
   optional parameter
   Pause after boot and root partitions mount. You can add/modify files.

-a MODULES_LIST
   MODULES_LIST="module1 module2 ...", optional parameter
   List of modules to download and copy to root image into MODULES_DESTINATION directory

-b MODULES_DESTINATION
   MODULES_DESTINATION=<ipk_directory_path>, optional parameter, default=/root/ipk/
   Directory on LEDE root partition to copy downloaded modules from MODULES_LIST

-s INITIAL_SCRIPT_PATH
   INITIAL_SCRIPT_PATH=<initial_script_path>, optional parameter, default=none
   Path to store initial configuration script on LEDE root partition. Example: /root/init_config.sh

-i INCLUDE_INITIAL_FILE
   MODULES_LIST=<include_initial_script_path>, optional parameter
   Path to local script, to be included in initial configuration script INITIAL_SCRIPT_PATH

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
```

Examples:

```
$ lede2rpi.sh -m Pi3 -r 17.01.1

$ lede2rpi.sh -m Pi2 -r 17.01.0

$ lede2rpi.sh -m Pi -r snapshot

$ lede2rpi.sh -m Pi3 -r 17.01.1 -d ~/tmp/ -p -s /root/init_config.sh -b /root/ipk -a "kmod-usb2 librt libusb-1.0 usb-modeswitch kmod-mii kmod-usb-net kmod-usb-net-cdc-ether terminfo libncurses nano"
```

Script generates files:
- LEDE_boot.tar.xz
- LEDE_root.tar.xz
- partition_setup.sh
- partitions.json
- os.json
- LEDE.png

in directory [WORKING_DIR]/lede2R[RASPBERRY_MODEL]_[LEDE_RELEASE]/LEDE

for example: lede2RPi3_snapshot/LEDE for Pi3 snapshot

Directory LEDE can be copied to SD card into /os folder for NOOBS/PINN installer.

Tested with Raspberry Pi 3 and NOOBS 2.4.0

## Requirements:
```
sudo apt install kpartx
```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details

