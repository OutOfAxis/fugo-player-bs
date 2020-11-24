# fugo-player-bs

### Getting Started

In repository, on main branch you can find ``` autorun.brs ``` which is the only required file.

### Prerequisites

SD Card should be formatted with FAT32 file system, that is Bright Sign recommendation. You can do it on MacOS by command

```
sudo diskutil eraseDisk FAT32 BBS MBRFormat /dev/disk2
```
where `/dev/disk2` should be replace by path to SD Card which can be found by running command and `BBS` is name (note: only chars allowed in name field)

```
sudo diskutil
```

### Deploying

The `autorun.brs` file should be copied into root directory on SD Card.

### Console And Logs

`Administration Panel` is available on device listening IP. You can check IP via local network router or by running device without SD card, look at following image:

![](https://i.imgur.com/06KLgN1.jpg)

Username: **admin**

Password: **serial number**

_Under the device or line under IP address you can find serial number._

Moreover, on SD card device is logging into files `log.txt`
