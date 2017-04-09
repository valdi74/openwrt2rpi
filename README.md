# lede2rpi
converting lede img to RPi NOOBS format

  Usage: lede2rpi.sh Pi|Pi2|Pi3 LEDE_RELEASE|snapshot

Example: lede2rpi.sh Pi3 snapshot
         lede2rpi.sh Pi2 17.01.0
         lede2rpi.sh Pi  17.01.1

Generates files:
- boot.tar.xz
- root.tar.xz
- partition_setup.sh
- partitions.json
- os.json
- LEDE.png

in directory /tmp/lede2R[PI_MODEL]_[RELEASE]
lede2RPi3_snapshot for Pi3 snapshot

yet not tested with RPi, i have no free SD card :-)
