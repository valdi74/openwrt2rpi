# lede2rpi
downloading and converting LEDE img to Raspberry Pi NOOBS/PINN installer format

  Usage: lede2rpi.sh Pi|Pi2|Pi3 LEDE_RELEASE|snapshot

Examples:

lede2rpi.sh Pi3 snapshot

lede2rpi.sh Pi2 17.01.0

lede2rpi.sh Pi  17.01.1

Script generates files:
- LEDE_boot.tar.xz
- LEDE_root.tar.xz
- partition_setup.sh
- partitions.json
- os.json
- LEDE.png

in directory /tmp/lede2R[PI_MODEL]_[RELEASE]/LEDE

for example: lede2RPi3_snapshot/LEDE for Pi3 snapshot

Directory LEDE can be copied to SD card into /os folder for NOOBS/PINN installer.

Tested with Raspberry Pi 3 and NOOBS 2.4.0

## Requirements:
```
sudo apt install kpartx
```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details

