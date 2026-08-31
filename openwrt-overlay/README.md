# OpenWrt overlay

Copy this directory over a matching OpenWrt 25.12 source tree, preserving paths.

The overlay contains the complete uM310R board files and the imported FullCone
NAT integration recovered from the tested build tree. Temporary `.orig` and
`.rej` files were intentionally excluded.

The public copy does not embed carrier authentication credentials. Configure
the APN, username, and password in LuCI or UCI before bringing up `wan` when the
SIM requires them. The APN currently defaults to `plus.acs.jp.v6`.

The hardware uses an AR9350 SoC with AR9344-compatible ath79 support, so the DTS
filename and `SOC := ar9344` build selector are intentional. The unit has
128 MiB RAM.
