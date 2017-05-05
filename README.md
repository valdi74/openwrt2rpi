# lede2rpi
Linux shell script for downloading and converting LEDE image to Raspberry Pi NOOBS/PINN installer format.

Script generates files:
- [BOOT_PART_LABEL].tar.xz
- [ROOT_PART_LABEL].tar.xz
- partition_setup.sh
- partitions.json
- os.json
- [LEDE_OS_NAME].png

in directory [WORKING_DIR]/lede2R[RASPBERRY_MODEL]_[LEDE_RELEASE]/LEDE

for example: lede2RPi3_snapshot/LEDE for Pi3 snapshot

Directory LEDE can be copied to SD card into /os folder for NOOBS/PINN installer.

Optionally script downloads selected modules to root partition and creates initial configuration script.

Tested on Ubuntu 16.04 with Raspberry Pi 3 and NOOBS 2.4.0 / PINN 2.3.1a BETA

## Usage
```
$ lede2rpi.sh -m RASPBERRY_MODEL -r LEDE_RELEASE [OPTIONS]

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

-h
   Display help and exit.
```

### Examples

Download LEDE release 17.01.1 for RPi 3 and convert to NOOBS with default parameters:
```
$ lede2rpi.sh -m Pi3 -r 17.01.1
```

Download LEDE release 17.01.0 for RPi 2 and convert to NOOBS with default parameters:
```
$ lede2rpi.sh -m Pi2 -r 17.01.0
```

Download LEDE development snapshot for RPi 1 and convert to NOOBS with quiet mode:
```
$ lede2rpi.sh -m Pi -r snapshot -q
```

Download LEDE release 17.01.1 for Raspberry Pi 3, be verbose, use working dir ~/tmp/, create initial config script in /root/init_config.sh and run it once (through rc.local), include local init script ~/tmp/my_lede_init.sh, download modules for HiLink modem and nano to /root/ipk directory and pause befor making final files. Boot partition will have a size of 30 MB and the root partition will have a size of 400 MB. Final files will be created in the directory ~/tmp/lede2RPi3_17.01.1/LEDE.
```
$ lede2rpi.sh -m Pi3 -r 17.01.1 -d ~/tmp/ -v -p -c -s /root/init_config.sh -i ./user_lede_init.sh -b /root/ipk -a "kmod-usb-ehci kmod-usb2 librt libusb-1.0 usb-modeswitch kmod-mii kmod-usb-net kmod-usb-net-cdc-ether terminfo libncurses nano" -k 30 -l 400
```

Sample local init file user_lede_init.sh sets local IP address, timezone (Warsaw), enables WPA2 secured Wifi AP, sets USB HiLink modem as wan interface and makes simple script for shutdown button on GPIO 22. Finally waits 10 sec and reboots RPi.

## Requirements
```
sudo apt install kpartx
```
## To do / roadmap
- waiting for sugestions

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details

