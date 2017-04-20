# lede2rpi
converting lede img to RPi NOOBS format

  Usage: lede2rpi.sh Pi|Pi2|Pi3 LEDE_RELEASE|snapshot

Example: lede2rpi.sh Pi3 snapshot
         lede2rpi.sh Pi2 17.01.0
         lede2rpi.sh Pi  17.01.1

Generate files:
- boot.tar.xz
- root.tar.xz
- partition_setup.sh
- partitions.json
- os.json
- LEDE.png

in directory /tmp/lede2R[PI_MODEL]_[RELEASE]/noobs_lede
for example: lede2RPi3_snapshot/noobs_lede for Pi3 snapshot

Directory noobs_lede can be copied to SD card into /os folder.

Tested with RPi 3

## Requirements:
```
sudo apt install kpartx
```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details

