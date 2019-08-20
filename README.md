# openwrt2rpi #
Linux shell script for downloading and converting OpenWrt image to Raspberry Pi NOOBS or PINN installer format.

Script generates files:
- [BOOT_PART_LABEL].tar.xz
- [ROOT_PART_LABEL].tar.xz
- partition_setup.sh
- partitions.json
- os.json
- [OPENWRT_OS_NAME].png
- marketing.tar

in directory [WORKING_DIR]/openwrt2R[RASPBERRY_MODEL]_[OPENWRT_RELEASE]/openwrt2R[RASPBERRY_MODEL]

for example: openwrt2RPi3_snapshot/openwrt2RPi3 for Pi3 snapshot

Directory openwrt2R[RASPBERRY_MODEL] can be copied to SD card into /os folder for NOOBS/PINN installer.

Optionally script downloads selected modules to root partition and creates initial configuration script.
It's useful when Pi don't have internet connection after install (only USB modem for example).

Tested on Ubuntu 16.04 with Raspberry Pi 3 and NOOBS 2.4.0 / PINN 2.4.2 and OpenWrt 18.06.3/snapshot

Script uses sudo and will ask for admin password to mount and modify system files to OpenWrt partitions.

## Usage ##
```
$ openwrt2rpi.sh -m RASPBERRY_MODEL -r OPENWRT_RELEASE [OPTIONS]

OPTIONS:

-m raspberry_model
   raspberry_model=Pi|Pi2|Pi3, mandatory parameter

-r openwrt_release
   openwrt_release=snapshot|18.06.2|18.06.3|future_release_name, mandatory parameter

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
    - m_adblock - OpenWrt adblock module (includes full wget)
    - m_all - all above modules
    - m_none - no modules download

-b modules_destination
   modules_destination=<ipk_directory_path>, optional parameter, default=/root/ipk
   Directory on OpenWrt root partition to copy downloaded modules from modules_list

-s initial_script_path
   initial_script_path=<initial_script_path>, optional parameter, default=none
   Path to store initial configuration script on OpenWrt root partition. Example: /root/init_config.sh

-i include_initial_file
   include_initial_file=<include_initial_script_path>, optional parameter
   Path to local script, to be included in initial configuration script initial_script_path.

-g run_command_after_mount
   run_command_after_mount=<command_to_run>, optional parameter
   Command to run after boot and root partitions mount.
   The command will receive two parameters: boot and root partitions mount directory.

-c
   optional parameter, default=no autorun initial script
   Run initial script initial_script_path once. Path to initial script will be added do /etc/rc.local and removed after first run.

-k openwrt_boot_part_size
   openwrt_boot_part_size=<boot_partition_size_in_mb>, optional parameter, default=25
   OpenWrt boot partition size in MB.

-l openwrt_root_part_size
   openwrt_root_part_size=<root_partition_size_in_mb>, optional parameter, default=300
   OpenWrt root partition size in MB.

-n boot_part_label
   boot_part_label=<boot_partition_label>, optional parameter, default=OpenWrt_boot
   OpenWrt boot partition label.

-e root_part_label
   root_part_label=<root_partition_label>, optional parameter, default=OpenWrt_root
   OpenWrt root partition label.

-o openwrt_os_name
   openwrt_os_name=<openwrt_os_name>, optional parameter, default=OpenWrt
   OpenWrt os name in os.json

-q
   optional parameter, default=no quiet
   quiet mode.

-v
   optional parameter, default=no verbose
   verbose mode.

-u upgrade_partitions
   upgrade_partitions='BOOT=<RPi_boot_dev>:<local_boot_dir>,ROOT=<RPi_root_dev>:<local_root_dir>', optional parameter
   Upgrade existing OpenWrt instalation. Use with care! You shouldn't use this option unless you know what you are doing.
   WARNING: all files from <local_boot_dir> and <local_root_dir> will be DELETED.
   example: -u BOOT=/dev/mmcblk0p6:/media/$USER/OpenWrt_boot,ROOT=/dev/mmcblk0p7:/media/$USER/OpenWrt_root
   Assume that:
    - boot partition on RPi is /dev/mmcblk0p6
    - boot partition is now mounted in /media/$USER/OpenWrt_boot
    - root partition on RPi is /dev/mmcblk0p7
    - root partition is now mounted in /media/$USER/OpenWrt_root

-w
   optional parameter, default=generate NOOBS/PINN files
   Don't generate NOOBS/PINN files in OpenWrt directory. Useful with -u (only upgrade).

-t
   optional parameter, default=delete temporary files
   Don't delete temporary files (OpenWrt image, ipk, etc.)

-j os_list_binaries_url
   optional parameter, default=<empty> -> don't generate 
   Create (append mode) os_list_openwrt.json for NOOBS/PINN on-line installation.
   File will be created in <working_dir> directory.
   Destination URL=<os_list_binaries_url><raspberry_model>/[os_setup_filename], exmaple:
   - os_list_binaries_url="http://downloads.sourceforge.net/project/pinn/os/lede2R"
   - raspberry_model="Pi2"
   Result URL for "os_info":
   "http://downloads.sourceforge.net/project/pinn/os/lede2RPi2/os.json"

-h
   Display help and exit.
```


### Examples ###

Download OpenWrt release 18.06.3 for RPi 3 and convert to NOOBS with default parameters:
```
$ openwrt2rpi.sh -m Pi3 -r 18.06.3
```

Download OpenWrt release 18.06.3 for RPi 2 and convert to NOOBS with default parameters:
```
$ openwrt2rpi.sh -m Pi2 -r 18.06.3
```

Download OpenWrt development snapshot for RPi 1 and convert to NOOBS with quiet mode:
```
$ openwrt2rpi.sh -m Pi -r snapshot -q
```

Download OpenWrt release 18.06.2 for Raspberry Pi 3, be verbose, use working dir ~/tmp/, create initial config script in /root/init_config.sh and run it once (through rc.local), include local init script ~/tmp/my_openwrt_init.sh, download modules for HiLink modem, nano and USB relay to /root/ipk directory and pause befor making final files. Boot partition will have a size of 30 MB and the root partition will have a size of 400 MB. Final files will be created in the directory ~/tmp/openwrt2RPi3_18.01.1/OpenWrt.
```
$ openwrt2rpi.sh -m Pi3 -r 18.06.2 -d ~/tmp/ -v -p -c -s /root/init_config.sh -i ./user_openwrt_init.sh -b /root/ipk -a "m_modem_hilink m_nano m_crelay" -k 30 -l 400
```

Sample local init file user_openwrt_init.sh sets local IP address, timezone (Warsaw), enables WPA2 secured Wifi AP, sets USB HiLink modem as wan interface and makes simple script for shutdown button on GPIO 22. Finally waits 10 sec and reboots RPi.

## Requirements ##
```
sudo apt install kpartx
```
## To do / roadmap ##
- waiting for sugestions

# make_pinn_release #
Linux shell script for creating complete PINN installation of OpenWrt for Raspberry Pi models 1, 2 & 3 with pre-downloaded modules (in /root/ipk).

Generates files:
- openwrt2RPi_[openwrt_release].tar
- openwrt2RPi2_[openwrt_release].tar
- openwrt2RPi3_[openwrt_release].tar
- os_list_openwrt.json

It uses openwrt2rpi.sh to generate single Pi image.

## Usage ##
```
$ make_pinn_release.sh OpenWrt_release [list_of_module_sets] [os_list_binaries_url]

OPTIONS:

OpenWrt_release=snapshot|18.06.2|18.06.3|future_release_name, mandatory parameter

list_of_module_sets="m_set1 m_set2 ..."
    List of modules or predefined module sets, to be downloaded offline.

os_list_binaries_url
    URL to os binaries to set in os_list_openwrt.json file.
```

### Example ###

Create OpenWrt complete release 18.06.3 with pre-downloaded modules for HiLink modem, nano and crelay:
```
$ make_pinn_release.sh 18.06.3 "m_modem_hilink m_nano m_crelay"
```

## License ##

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details

OpenWrt logo and other gfx are distributed on CC BY-SA 4.0 license (https://creativecommons.org/licenses/by-sa/4.0/)

