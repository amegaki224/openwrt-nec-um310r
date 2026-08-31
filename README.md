# OpenWrt support for NEC Magnus uM310R

Community bring-up work for the NEC Magnus Communications uM310R A1 router,
based on the Qualcomm Atheros AR9344 SoC and an AM Telecom AMM570 LTE modem.

This repository currently contains the reviewed patch set and hardware notes
recovered during device bring-up. The complete OpenWrt build-tree diff and
reproducible build instructions will be added from the build server.

## Confirmed hardware

- SoC: Qualcomm Atheros AR9344
- Flash: 16 MiB SPI NOR, 64 KiB erase blocks
- RAM: 64 MiB
- WLAN: integrated 2.4 GHz ath9k WMAC
- LTE: AM Telecom AMM570, PPP data on `/dev/ttyACM0`, AT control on `/dev/ttyUSB1`
- Ethernet: two LAN ports through the integrated switch
- LED GPIO mapping:
  - ANT green/red: GPIO 0/1, active high
  - COM green/red: GPIO 2/3, active high
  - WLAN green: GPIO 13, active low
  - LAN1/LAN2: switch LED functions on GPIO 19/20
  - ALM green/red: GPIO 21/22, active low
  - PWR is hardware-controlled

## Implemented and tested

- ath79 DTS and stock flash partition layout
- AMM570 power sequencing and netifd PPP protocol
- IPv4/IPv6 dual stack
- RFC 7278 `EXTENDPREFIX=1` fallback for mobile networks that provide a routed
  `/64` but no DHCPv6-PD
- delayed PPP up hook to avoid the netifd address-notification race
- automatic ANT/COM/ALM/WLAN LED status handling
- BBR kernel module packaging
- nftables FullCone NAT support imported from ImmortalWrt

BBR and FullCone NAT are included in the tested firmware but intentionally are
not enabled by default. FullCone is configured in the firewall `defaults`
section by the imported firewall4 implementation, not directly on the WAN zone.

## Patch order

Apply the patches in `patches/` in numeric order against the matching uM310R
OpenWrt 25.12 working tree:

1. `0001-um310r-board-leds.patch`
2. `0002-um310r-automatic-leds.patch`
3. `0003-um310r-ppp-netifd-race-fix.patch`

These are incremental patches produced during bring-up. They do not yet include
the initial board DTS, AMM570 package, RFC 7278 integration, or the imported
FullCone patch stack; those remain in the build server tree and are pending a
complete export.

## U-Boot reset warning

The stock U-Boot has a board-specific automatic-boot path that can leave GPIO15
in the wrong state. On affected units this causes an external watchdog or MCU to
reset the board roughly 33 seconds after automatic boot, while manually choosing
`OP` works normally. See
[`docs/u-boot-33s-reset-analysis.md`](docs/u-boot-33s-reset-analysis.md) before
changing `bootcmd` or relying on unattended boot.

Do not overwrite the bootloader, ART calibration data, U-Boot environment, or
device configuration partitions. Device-specific dumps are deliberately not
included in this repository.

## Tested firmware geometry

- Firmware partition: `0x9f7c0000` through `0x9ff0ffff` (`0x750000` bytes)
- Tested factory image size: `7,208,964` bytes (`0x6e0004`)
- Remaining partition space: `458,748` bytes
- Tested factory image SHA-256:
  `55643dea4dca60d6a0c5c5b15baee8085d60eb6784995e990d2c2e819e77d1ff`
- Tested RAM-image CRC32 before flashing: `1ebb04eb`

Always verify the downloaded image checksum, `iminfo`, and RAM/flash CRC before
booting. Keep serial access and a known-good recovery image available.

## Data not published

The following are intentionally excluded:

- stock firmware and U-Boot binaries
- ART/calibration, environment, `devconf`, and management partitions
- modem or carrier credentials
- logs that may contain addresses, identifiers, or passwords

OpenWrt-derived files retain the license terms and SPDX identifiers of their
respective upstream files.
