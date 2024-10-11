# Yubikey Challenge-Response Disk Encryption
This package allows you to unlock your LUKS volumes with Yubikey and your password, meaning it uses 2-factor authentication.

Useful for root (/) on LUKS container.

Works on both **systemd** and **busybox** initramfs.

The Busybox hook isn't fully tested but should work.

The Systemd hook is my daily driver and is expected to work.

Written for and tested on **Archlinux**. Might not work on other distributions.

Read through the whole README to understand fully how `ykchrde` works and the recommended usage.
# Disclaimer
This is a project that I threw together over a few nights for my personal use. Even though I made it to the best of my abilities and will try to keep it updated, I don't guarantee that it will work or is secure. Use at your own risk.
# Prerequisites
This guide assumes you have fully bootable Archlinux on LUKS and Yubikey with one of its slots in challenge-response mode.

Most of these commands need to be run as root. This guide assumes you are the root user; if not, use sudo.
# Install
To install this package, clone this repository and run `makepkg -si`

```
git clone https://github.com/peto59/yubikey-challange-response-disk-encryption.git
cd yubikey-challenge-response-disk-encryption
makepkg -si
```
## Manual install
**This is untested!**

In theory, this should run in any system with mkinitcpio.
To manually install this package, copy these files to these directories:
```
src/ykchrde.conf => /etc/ykchrde.conf
src/ykchrde.sh => /usr/bin/ykchrde.sh
src/hooks/ykchrde => /usr/lib/initcpio/hooks/ykchrde
src/install/ykchrde => /usr/lib/initcpio/install/ykchrde
src/install/sd-ykchrde => /usr/lib/initcpio/install/sd-ykchrde
```
And set these permissions
```
chmod 600 /etc/ykchrde.conf
chmod 700 /usr/bin/ykchrde.sh
chmod 644 /usr/lib/initcpio/hooks/ykchrde
chmod 644 /usr/lib/initcpio/install/ykchrde
chmod 644 /usr/lib/initcpio/install/sd-ykchrde
```
## Hooks
### systemd initramfs
Edit /etc/mkinitcpio.conf

add `sd-ykchrde` to HOOKS=() after block but before `sd-encrypt`

`HOOKS=( ... block sd-ykchrde sd-encrypt filesystems ... )`

You may **not** remove the `sd-encrypt` hook

You can delete entries of disk(s) opened through `sd-ykchrde` from `/etc/crypttab.initramfs` **after** finishing the configuration of `ykchrde` and testing it.
### busybox initramfs
Edit /etc/mkinitcpio.conf

add `ykchrde` to HOOKS=() after block but before `encrypt`

`HOOKS=( ... block ykchrde encrypt filesystems ... )`

You may **not** remove the `encrypt` hook

You can delete entries of disk(s) opened through `ykchrde` from `/etc/crypttab` **after** finishing the configuration of `ykchrde` and testing it.
# Configuration
## Disks
To open a disk or a partition at boot, edit `/etc/ykchrde.conf`
```
nano /etc/ykchrde.conf
```
Add these lines:
```
[drive]
uuid = <uuid>
name = <name>
```
Where `<uuid>` is the UUID of the LUKS container you wish to open, and `<name> `is the mapping of this container.

For example:
```
[drive]
uuid = 709cbfb7-7873-4b1a-953a-820f3510c131
name = test
```
Will open disk with UUID of `709cbfb7-7873-4b1a-953a-820f3510c131` and map it to `/dev/mapper/test`

You may add multiple of these entries to open multiple disks or partitions (just remember that you will need to touch your Yubikey as many times as you have listed drives)

For example:
```
[drive]
uuid = 709cbfb7-7873-4b1a-953a-820f3510c131
name = test
[drive]
uuid = ababab-aaaa-bbbb-1111-121212121212
name = my_crypt
```
This will try to open `/dev/disk/by-uuid/709cbfb7-7873-4b1a-953a-820f3510c131` and map it to `/dev/mapper/test` and `/dev/disk/by-uuid/ababab-aaaa-bbbb-1111-121212121212` and map it to `/dev/mapper/my_crypt`

To get the UUID of the disk or partition, run `blkid`
For example:
```
blkid /dev/sda -s UUID -o value
```
or
```
blkid /dev/sda3 -s UUID -o value
```
If this does not return any value, it probably means that this disk or partition is not an LUKS container.

**REMEMBER TO REGENERATE INITRAMFS AFTER EDITING `/etc/ykchrde.conf`**
You can do this with:
```
mkinitcpio -P
```
## Yubikeys
`ykchrde` uses Yubikey's first slot by default. This can be changed.

To change which slot is used, edit `/etc/ykchrde.conf`
```
nano /etc/ykchrde.conf
```
Add these lines:
```
[yubikey]
serial = <serial>
slot = <slot>
```
Where `<serial>` is the serial number of your Yubikey and `<slot>` is the slot you want to use. On Yubikey 5 NFC valid values for `<slot>` are 1 or 2.

For example:
```
[yubikey]
serial = 12332155
slot = 2
```
This will use the second challenge-response slot of Yubikey with serial `12332155`

You may add multiple of these entries if using multiple yubikeys.

For example:
```
[yubikey]
serial = 12332155
slot = 2
[yubikey]
serial = 58963298
slot = 1
```
This will use the second challenge-response slot of Yubikey with serial `12332155` and the first challenge-response slot of Yubikey with serial `58963298 `, but as the first slot is used by default, the second entry could be omitted.

**REMEMBER TO REGENERATE INITRAMFS AFTER EDITING `/etc/ykchrde.conf`**
You can do this with:
```
mkinitcpio -P
```
# Recovery
If you need to chroot into the machine, you need to unlock the LUKS container, which may prove difficult if you don't have `ykchrde` installed.

To open the `ykchrde` encrypted LUKS container without `ykchrde`, you need to have yubikey-personalization installed to have access to `ykchalresp`.

Afterwards, run this command where `$password` is the password you used when enrolling password to the LUKS container, `$uuid` is the UUID of the container you wish to open, `$yubikey_slot` is the slot on the Yubikey which is used for challenge-response, `$disk` is the disk or partition and `$mapping` is the name under which you wish to open the container. **Don't forget the `|` between $password nad $uuid.**
```
echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | ykchalresp -$yubikey_slot -i - | sha512sum | awk '{print $1}' | cryptsetup open $disk $mapping
```
For example:
```
echo -n "test123|709cbfb7-7873-4b1a-953a-820f3510c131" | sha512sum | awk '{print $1}' | ykchalresp -2 -i - | sha512sum | awk '{print $1}' | cryptsetup open /dev/disk/by-uuid/709cbfb7-7873-4b1a-953a-820f3510c131 my_crypt
```
This will open the disk with UUID of `709cbfb7-7873-4b1a-953a-820f3510c131` with user-entered password `test123` using the second slot of inserted Yubikey and map it to `/dev/mapper/my_crypt`.

To get the UUID of the disk or partition, run `blkid`
For example:
```
blkid /dev/sda -s UUID -o value
```
or
```
blkid /dev/sda3 -s UUID -o value
```
If this does not return any value, it probably means that this disk or partition is not an LUKS container.

# Usage
## Enrolling new key
To enroll a new password into the LUKS container, use:
```
ykchrde.sh enroll -d <disk>
```
Where <disk> is the disk or partition into which you wish to enroll the new key.

This will ask you to enter any existing LUKS password and then to enter your new password and repeat your new password. Remember to touch your Yubikey when it starts blinking.

If you wish to enroll multiple passwords with the **same** challenge-response secret, rerun the command above and enter a new password each time as long as **you have not deleted your original non-yubikey password**. If you have deleted your original non-yubikey password, refer to the **`Enroling additional keys`** section below.

Suppose you wish to enroll multiple passwords with **different** challenge-response secrets. In that case, you can rerun the command above and enter a new password each time as long as **you have not deleted your original non-yubikey password**. If you have deleted your original non-yubikey password, refer to the **`Recovery`** section above on how to obtain your Yubikey password and use it to enroll in a new interactive non-yubikey password.

For example:
```
ykchrde.sh enroll -d /dev/sda3
```
This will enroll a new key to the LUKS container on /dev/sda3

Alternatively, you may use `-u <uuid>` instead if `-d <device>`. `-u <uuid>` option will try to enroll the key into a disk or a partition `/dev/disk/by-uuid/<uuid>` so enter UUID only and not full path.

To get the UUID of the disk or partition, run `blkid`
For example:
```
blkid /dev/sda -s UUID -o value
```
or
```
blkid /dev/sda3 -s UUID -o value
```
If this does not return any value, it probably means that this disk or partition is not an LUKS container.

**After** rebooting to test that everything works as expected **and** backing up your LUKS header to a safe place on an external medium, you may delete your original non-yubikey password. Deleting the original non-yubikey password is encouraged to increase security **but only after** testing that everything works as expected **and** backing up your LUKS header to a safe place on an external medium.

To backup your LUKS header, you can use:
```
sudo cryptsetup luksHeaderBackup <device> --header-backup-file <destination>
```
Where `<device>` is the device of which you want to backup the LUKS header, and `<destination>` is the place where you want to store your backup.

For example:
```
sudo cryptsetup luksHeaderBackup /dev/sda3 --header-backup-file /mnt/usb/sda3.luks.backup
```
will back up the LUKS header of `/dev/sda3` into file `/mnt/usb/sda3.luks.backup`

**Make sure to store the medium to which you've backed up your LUKS header in a safe place, as an attacker who gained access to your LUKS header could circumvent `ykchrde`.**

To restore the LUKS header if anything goes wrong, use:
```
cryptsetup luksHeaderRestore <device> --header-backup-file <destination>
```
Where `<device>` is the device to which you want to restore the LUKS header, and `<destination>` is the place where your backup is stored.

For example:
```
sudo cryptsetup luksHeaderRestore /dev/sda3 --header-backup-file /mnt/usb/sda3.luks.backup
```
will restore the LUKS header of `/dev/sda3` from file `/mnt/usb/sda3.luks.backup`

To delete your original non-yubikey password, use:
```
sudo cryptsetup luksRemoveKey <device>
```
This will ask you to enter the password you wish to remove from `<device>`

For example:
```
sudo cryptsetup luksRemoveKey /dev/sda3
```
Will delete the password that you enter from `/dev/sda3`

Deleting the original non-yubikey password is encouraged to increase security **but only after** testing that everything works as expected **and** backing up your LUKS header to a safe place on an external medium.

## Enrolling additional keys
If you wish to enroll multiple passwords with the **same** challenge-response secret use:
```
ykchrde.sh enroll-additional -d <disk>
```
Where <disk> is the disk or partition into which you wish to enroll a new key.

This will ask you to enter any existing LUKS password and then to enter your new password and repeat your new password. Remember to touch your Yubikey twice.

If you wish to enroll multiple passwords with **different** challenge-response secrets, refer to the **'Enrolling new key'** section above as long as **you have not deleted your original non-yubikey password**. If you have deleted your original non-yubikey password, refer to the **`Recovery`** section above on how to obtain your Yubikey password and use it to enroll a new interactive non-yubikey password.

For example:
```
ykchrde.sh enroll-additional -d /dev/sda3
```
This will enroll a new key to the LUKS container on /dev/sda3

Alternatively, you may use `-u <uuid>` instead if `-d <device>`. `-u <uuid>` option will try to enroll the key into the disk or partition `/dev/disk/by-uuid/<uuid>` so enter UUID only and not full path.

To get the UUID of the disk or partition, run `blkid`
For example:
```
blkid /dev/sda -s UUID -o value
```
or
```
blkid /dev/sda3 -s UUID -o value
```
If this does not return any value, it probably means that this disk or partition is not an LUKS container.

## Opening encrypted partition or disk
To open the `ykchrde` encrypted LUKS container, use:
```
ykchrde.sh open -d <disk> -n <name>
```
Where `<disk>` is the disk or partitions you wish to open and `<name>` is the name under which you want to map it into `/dev/mapper/`.

This will ask you to enter your password. Remember to touch your Yubikey when it starts blinking.

For example:
```
ykchrde.sh open -d /dev/sda3 -n my_crypt
```
This will open the LUKS container on `/dev/sda3` and map it to `/dev/mapper/my_crypt`.

Alternatively, you may omit the `-d <device>` and `-n <name>` options. In this case, `ykchrde` will try to read config at `/etc/ykchrde.conf` and open all disks and partitions listed in it.

Alternatively, you may use `-u <uuid>` instead if `-d <device>`. `-u <uuid>` option will try to open disk or partition `/dev/disk/by-uuid/<uuid>` so enter UUID only and not full path.

To get the UUID of the disk or partition, run `blkid`
For example:
```
blkid /dev/sda -s UUID -o value
```
or
```
blkid /dev/sda3 -s UUID -o value
```
If this does not return any value, it probably means that this disk or partition is not an LUKS container.

# Limitations
Using multiple Yubikeys, each with a different secret, is tedious but possible.

~~The tcl version needs to be 8.6. Using a different tcl version won't work. If a newer version of tcl comes out, I'll try to update this to the latest version. If I forget or you need help using an older version of tcl, create an issue, and I'll try to help you.~~

`ykchrde` does not depend on any specific version of any package.

Currently, no rolling or randomised secret is used. If you have a good reason to implement this and any suggestions on **how** to implement it, create PR or an issue.

# Whitepaper
Password is generated with this snippet of code
```
echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | ykchalresp -$yubikey_slot -i - | sha512sum | awk '{print $1}'
```
Where `$password` is the password entered by the user and `$uuid` is the UUID of the disk you wish to open. Don't forget to include the `|` to separate the password and UUID. Lastly, `$yubikey_slot` is the slot used for challenge response.

The output of this is then used in cryptsetup.

This ensures that even if the password is brute-forced/leaked to one of the disks or partitions and these disks/partitions share the same user-entered password, the attacker won't gain access to other partitions. Of course, if the user-entered password is leaked, the attacker can access all partitions. If you believe you can improve this, create PR or an issue.
