# Flashing and recovery

These instructions are only for the NEC Magnus uM310R A1 hardware described in
this repository. Keep a 3.3 V serial console attached and retain full flash,
U-Boot, U-Boot environment, ART, and device-configuration backups.

The unit uses an AR9350 SoC with AR9344-compatible ath79 support and 128 MiB
RAM. Do not write the U-Boot, ART, environment, `devconf`, or management
partitions.

## Release files

- `openwrt-ath79-generic-nec_um310r-initramfs-kernel.bin`: temporary RAM boot
- `openwrt-ath79-generic-nec_um310r-squashfs-factory.bin`: direct U-Boot flash
- `openwrt-ath79-generic-nec_um310r-squashfs-sysupgrade.bin`: upgrade from a
  running compatible OpenWrt installation

The published binaries contain the carrier defaults `plus.acs.jp.v6`, `ym`,
and `ym`. Change them in LuCI or UCI when using another SIM or operator.

## Known stock U-Boot reset behavior

The stock U-Boot board initialization drives GPIO15 low. Its manual autoboot
interrupt path drives GPIO15 high, but the unattended `bootcmd` path does not.
When GPIO15 remains low, the external watchdog or management MCU resets the
unit after roughly 33 seconds.

The low-risk workaround sets only GPIO15 through the write-only-style GPIO SET
register before running the normal OpenWrt boot command:

```text
mw.l 0xb804000c 0x00008000 1
```

Do not replace the entire GPIO OE register. Board initialization has already
configured GPIO15 as an output, and a whole-register write could disturb other
GPIO functions.

Before flashing, interrupt autoboot manually and inspect the existing commands:

```text
printenv bootopenwrt
printenv bootcmd
md.l 0xb8040000 5
md.l 0xb8060008 2
```

Confirm that `bootopenwrt` boots the firmware at `0x9f7c0000`. Then install the
persistent workaround:

```text
setenv bootcmd 'mw.l 0xb804000c 0x00008000 1; run bootopenwrt'
printenv bootcmd
saveenv
```

After the final reboot, do not press a key and observe the system for at least
90 seconds. If it remains running, the automatic path is successfully raising
GPIO15 before Linux starts.

## Optional RAM-only test

Configure the U-Boot and TFTP-server addresses for your local network. The
values below are examples; change them if either address is already in use.

```text
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.2
tftpboot 0x81000000 openwrt-ath79-generic-nec_um310r-initramfs-kernel.bin
iminfo 0x81000000
crc32 0x81000000 ${filesize}
mw.l 0xb804000c 0x00008000 1
bootm 0x81000000
```

Expected initramfs values:

- size: `6946060` bytes (`0x69fd0c`)
- whole-file CRC32: `62be7c5e`
- SHA-256:
  `ff943e308d7475506b4f4534226ba07df08c383244ab249f2f9cd6dd584dc295`

## Direct U-Boot flash

Only the factory image is used for this procedure. The writable firmware
partition is `0x9f7c0000` through `0x9ff0ffff`, totaling `0x750000` bytes.

```text
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.2
tftpboot 0x81000000 openwrt-ath79-generic-nec_um310r-squashfs-factory.bin
printenv filesize
iminfo 0x81000000
crc32 0x81000000 ${filesize}
```

Do not erase anything unless all three checks match:

- `filesize=6e0004`
- `iminfo` reports a valid `MIPS OpenWrt Linux-6.12.103` image and checksum OK
- RAM CRC32 is `1ebb04eb`

When they match, erase exactly the firmware partition and copy exactly the
downloaded image length:

```text
erase 0x9f7c0000 0x9ff0ffff
cp.b 0x81000000 0x9f7c0000 ${filesize}
crc32 0x9f7c0000 ${filesize}
```

The flash CRC32 must also be `1ebb04eb`. Before resetting, make sure the GPIO15
workaround is saved:

```text
setenv bootcmd 'mw.l 0xb804000c 0x00008000 1; run bootopenwrt'
printenv bootcmd
saveenv
reset
```

If `tftpboot` is not present, use the stock U-Boot `tftp` command with the same
address and filename.

## Sysupgrade from OpenWrt

Verify the SHA-256, then perform a clean upgrade rather than preserving settings
from an unrelated or older build:

```sh
sha256sum /tmp/openwrt-ath79-generic-nec_um310r-squashfs-sysupgrade.bin
sysupgrade -n /tmp/openwrt-ath79-generic-nec_um310r-squashfs-sysupgrade.bin
```

Expected sysupgrade SHA-256:

```text
712d90021c5b1e45d82a09952898f16ebc62d195d8130b5f69436c7c738baec3
```

## Recovery notes

If unattended boot still resets, interrupt autoboot and manually run:

```text
mw.l 0xb804000c 0x00008000 1
run bootopenwrt
```

To restore the original automatic command, while accepting the original reset
behavior:

```text
setenv bootcmd 'run bootopenwrt'
saveenv
```

See [`u-boot-33s-reset-analysis.md`](u-boot-33s-reset-analysis.md) for the
register-level evidence and disassembly addresses behind this workaround.
