# Yubikey Challenge-Response Disk Encryption
This package allows you to unlock your LUKS volumes with Yubikey and your password, meaning it uses 2 factor authentication.

Works on both **systemd** and **busybox** initramfs.

Written for and tested on **Archlinux**. Might not work on other distributions.
## Prerequisites
This guide assumes you have fully bootable Archlinux on LUKS and Yubikey with one of its slots in challenge-response mode.

## Install
To install this package clone this repository and run `makepkg -si`

```
git clone https://github.com/peto59/yubikey-challange-response-disk-encryption.git
cd yubikey-challenge-response-disk-encryption
makepkg -si
```
### Manual install
**This is untested!**

In theory this should run in any system with mkinitcpio.
To manually install this package copy these files to these directories:
```
src/ykchrde.conf => /etc/ykchrde.conf
src/ykchrde.sh => /usr/bin/ykchrde.sh
src/hooks/ykchrde => /usr/lib/initcpio/hooks/ykchrde
src/install/ykchrde => /usr/lib/initcpio/install/ykchrde
src/install/sd-ykchrde => /usr/lib/initcpio/install/sd-ykchrde
```
And set these permissions
```
chmod 664 /etc/ykchrde.conf
chmod 755 /usr/bin/ykchrde.sh
chmod 664 /usr/lib/initcpio/hooks/ykchrde
chmod 664 /usr/lib/initcpio/install/ykchrde
chmod 664 /usr/lib/initcpio/install/sd-ykchrde
```
### Hooks
## Recovery
echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | ykchalresp -$yubikey_slot -i - | sha512sum | awk '{print $1}'
