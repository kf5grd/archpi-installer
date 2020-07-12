# ArchPi Installer
Automated scripts for installing and setting up Arch Linux ARM on Raspberry Pi boards

## Usage

### Creating a new image
To create a new image which includes the auto wpa and bootrunner scripts, run the following (assuming your Arch Linux ARM file -- from archlinuxarm.org -- is in the same directory as this script):

```shell
./install-arch.sh ArchLinuxARM-rpi-latest.tar.gz
```

This will result in a file called ArchPi-<date>-<hash>.img, which can be dd'd
directly onto your sdcard.

If you place your wpa_supplicant.conf and/or wlan0.network files in the same directory
as the install-arch.sh script, the script will also copy those to the boot folder,
which will cause them to be active at boot.

## WiFi Setup
See the instructions below for generating the `wpa_supplicant.conf` and `wlan0.network` config files. If either, or both of these files are present in the same folder as `install-arch.sh` when it is run, they will be copied to the boot partition of the resulting image and will be installed on first boot. If at any time you want to update the configuration, you can simply mount the boot partition of your Pi's SD card and copy the new files over. The new network files will be installed the next time the Pi boots.

### wpa_supplicant.conf
To set or change your WiFi SSID and password that the Pi connects to on boot, create a `wpa_supplicant.conf` file.

```shell
wpa_passphrase "YourSSID" "YourWirelessPassword" > wpa_supplicant.conf
```

### wlan0.network
To set a static IP address, or configure other networking features, you can create a file called `wlan0.network`, which will override the default profile.

Here's an example of a wlan0.network file with a static IP:

```
[Match]
Name=wlan0

[Network]
Address=192.168.0.10/24
Gateway=192.168.0.1
DNS=192.168.0.1
```

More information about these config files can be found on the [ArchWiki](https://wiki.archlinux.org/index.php/Systemd-networkd#Configuration_files)

## bootrunner
The bootrunner service allows you to place scripts to be run the next time the Pi boots

### Scripts
Before creating a new image, place any scripts you'd like to run on first boot in `files/bootrunner.d/run/`. These files will be copied into the image when you run `install-arch.sh` and will be run on first boot.

If you've already created your image and written it to your SD card, you can either copy your scripts to `/etc/bootrunner.d/run/` on a running system, or you can mount the 2nd partition of the SD card on another system, and copy files into the `run` folder.

Every time your Pi boots, the bootrunner service will run any scripts it finds at `/etc/bootrunner.d/run` and after each script it runs, it will move it to `/etc/bootrunner.d/done`. After all scripts in the folder have completed, if the file `/etc/bootrunner.d/reboot` exists, bootrunner will restart the system.

*Note: The bootrunner service will refuse to run any scripts if the `run` folder's permissions are not set to 700. This also means that you will need root access to read or write any scripts in that folder.*

You will find some helpful scripts in the `run` folder by default:

- **10-stop-resolved.sh** *Stops the systemd-resolved service on first boot, which can sometimes cause problems with a certain third-party 64bit image for the Raspberry Pi 4*
- **90-expand-root.sh** *Expands the root partition to fill up the rest of the SD card*

To prevent any of these from running, you can move them from `files/bootrunner.d/run` to `files/bootrunner.d/done` before creating your image.
