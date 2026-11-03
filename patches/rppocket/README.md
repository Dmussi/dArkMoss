# rppocket: Funnyplaying RetroPixel Pocket

RK3326, 1GB RAM, 3.1in 720x720 MIPI-DSI panel, RK817 PMIC/codec, odroidgo3-joypad
input with ADC-muxed analog sticks, Wi-Fi on SDIO. Stock firmware is a vendor
AmberELEC/EmuELEC fork (Rockchip 4.4.189 kernel, RG351MP-derived U-Boot).

## What this unit adds

| Piece | File |
|---|---|
| Kernel device tree (copied into christianhaitian/linux `rg351` at build time, Makefile line added) | `kernel/rk3326-rppocket-linux.dts` |
| U-Boot device tree + Makefile hook for christianhaitian/RG351MP-u-boot | `uboot/rppocket-uboot.dts`, `uboot/0001-arch-arm-dts-Makefile.patch` |
| Build script (xumini's pipeline, `UNIT=rppocket`) | `../../build_rppocket.sh` |
| Edits to existing scripts (run by `build_rppocket.sh`, idempotent) | `../../scripts/add-rppocket-unit.sh` |

Both device trees are the RG351MP trees (kernel and U-Boot) edited with the
RetroPixel's board values taken from the vendor's V1.1.3 DTBs: panel node (2 lanes,
720x720 @ 35 MHz, init/exit sequences), PMIC LDO rails, battery (3000 mAh, vendor OCV
table), backlight PWM, joypad (swapped ADC mux pins, F4 moved, BACKUP/BACKDOWN keys),
battery-low LED. Verified by compiling each and comparing against the vendor DTB with
phandles resolved: the kernel tree has 19 differences tree-wide, the U-Boot tree 5, all
intentional (property naming, bootargs, node names, phandle references).

U-Boot loads `uboot.dtb` through the existing `uboot-dtb` opt-in, exactly like xumini.
SCREEN_ROTATION stays 0 (the vendor cmdline uses `fbcon=rotate:0`).

## Not yet tested on hardware, in order of risk

1. **Panel supplies and enables.** The vendor panel node carries extra GPIO properties
   (`vspn-en`, `amp_en_gpio`, `vcc5v_en_gpio`, `wifi_vcc_en_gpio`, `vcc_en_gpio`,
   `bat_low_en_gpio`) that the vendor kernel's panel driver acts on. The `rg351` branch's
   `panel-simple.c` parses `panel-init-sequence` but not these, so the LCD bias, audio
   amp, 5V boost or Wi-Fi power may stay off. If the screen stays black or Wi-Fi/audio
   are dead, port that handling (or add gpio-hog/regulator-fixed nodes) in a second patch.
2. **Wi-Fi chip is unidentified.** The DTB has no wireless node; the vendor kernel
   probes the SDIO chip at runtime. Capture `lsmod`, `dmesg | grep -iE "wlan|sdio|rtl|brcm"`
   and `ls /sys/bus/sdio/devices/*/` on the stock firmware.
3. **Kernel opt-in fixes** (`patches/rk3326/kernel`: no-async-page-flip, vt-csi-ignore,
   rk817-gauge-capacity, rk817-plugin-online) are not enabled for this unit; add them to
   `KERNEL_OPTIN` in `build_kernel.sh` as they prove needed.
4. **Square panel in spruce.** `HW_DEVICE` is "RetroPixel Pocket", `SPRUCE_PLATFORM` is
   `RPPocket`. harbourmaster has no profile for it yet, so PortMaster falls back to 640x480
   until one exists; spruce needs `RPPocket` platform files (RGB30 is the closest 720x720
   reference). The shared U-Boot logo `logos/unrotated/dArkMoss.bmp` is not made for a
   square screen.
5. **Buttons.** F1-F4 and the two back keys (BACKUP/BACKDOWN) come through as extra
   keys; map them to spruce hotkeys.

## Building

Run **build-all** with unit `rppocket` from Actions, or `make rppocket` locally.
`build_rppocket.sh` first runs `scripts/add-rppocket-unit.sh`, which wires the unit
into `image_setup.sh`, `build_kernel.sh`, `setup_spruce_handoff.sh` and `build_update.sh`.
