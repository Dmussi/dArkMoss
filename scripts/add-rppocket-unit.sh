#!/bin/bash
# Wire the rppocket unit (Funnyplaying RetroPixel Pocket) into an existing
# dArkMoss checkout. build_rppocket.sh runs it first; it can also be run by hand
# from anywhere:
#
#   ./scripts/add-rppocket-unit.sh
#
# Idempotent: every edit is skipped if it is already there, and it stops with a
# message when an anchor line it expects is missing (the files changed).
set -e
cd "$(dirname "$0")/.."

python3 - <<'PY'
import re, sys

def edit(path, fn):
    s = open(path).read()
    new = fn(s)
    if new == s:
        print(f"unchanged  {path}")
    else:
        open(path, "w").write(new)
        print(f"edited     {path}")

def need(cond, msg):
    if not cond:
        sys.exit("ERROR: " + msg)

# --- case lines in setup_spruce_handoff.sh and build_update.sh ---------------
def case_line(anchor, line):
    def f(s):
        if line.strip() in s:
            return s
        need(anchor in s, f"anchor not found: {anchor.strip()}")
        return s.replace(anchor, anchor + "\n" + line, 1)
    return f

edit("setup_spruce_handoff.sh", case_line(
    '  xumini)    HW_DEVICE_NAME="XU Mini M" ;;',
    '  rppocket)  HW_DEVICE_NAME="RetroPixel Pocket" ;;'))
edit("setup_spruce_handoff.sh", case_line(
    '  xumini)    SPRUCE_PLATFORM_NAME="XUMiniM" ;;',
    '  rppocket)  SPRUCE_PLATFORM_NAME="RPPocket" ;;'))
edit("build_update.sh", case_line(
    '  xumini)    DMUPD_PLATFORM="XUMiniM" ;;',
    '  rppocket)  DMUPD_PLATFORM="RPPocket" ;;'))

# --- build_kernel.sh: add our device tree, like xumini's block ---------------
KB = '''if [ "$UNIT" == "rppocket" ]; then
  # christianhaitian/linux's rg351 branch has no RetroPixel Pocket board: build
  # its device tree from the board dts plus the power-gate dtsi (see
  # patches/rppocket/README.md) and add it to the Makefile.
  KDTS=$KERNEL_SRC/arch/arm64/boot/dts/rockchip
  cat "$PWD"/patches/rppocket/kernel/rk3326-rppocket-linux.dts \\
      "$PWD"/patches/rppocket/kernel/rk3326-rppocket-power.dtsi > $KDTS/rk3326-rppocket-linux.dts
  grep -q rk3326-rppocket-linux.dtb $KDTS/Makefile || \\
    sed -i 's/^\\(dtb-\\$(CONFIG_ARCH_ROCKCHIP) += rk3326-a10mini-v4-linux.dtb\\)$/\\1\\ndtb-$(CONFIG_ARCH_ROCKCHIP) += rk3326-rppocket-linux.dtb/' $KDTS/Makefile
  grep -q rk3326-rppocket-linux.dtb $KDTS/Makefile
  verify_action
fi
'''
def kernel(s):
    if 'UNIT" == "rppocket"' in s:
        return s
    anchor = "cd $KERNEL_SRC\n"
    need(s.count("\n" + anchor) == 1, "build_kernel.sh: 'cd $KERNEL_SRC' anchor not unique")
    return s.replace("\n" + anchor, "\n" + KB + anchor, 1)
edit("build_kernel.sh", kernel)

# --- image_setup.sh: U-Boot clone, dts patch, opt-in, dtb copy ---------------
UB = '''if [ "$UNIT" == "rppocket" ]; then
  # rppocket-uboot.dts is rg351mp-uboot.dts with the RetroPixel's board values;
  # RG351MP-u-boot has no such unit upstream.
  patch -p1 < ../patches/rppocket/uboot/0001-arch-arm-dts-Makefile.patch
  verify_action
  cp ../patches/rppocket/uboot/rppocket-uboot.dts arch/arm/dts/
fi
'''
def image(s):
    if 'UNIT" == "rppocket"' in s:
        return s
    old = '|| [ "$UNIT" == "xumini" ]; then'
    need(s.count(old) == 2, "image_setup.sh: expected 2 xumini conditions")
    s = s.replace(old, '|| [ "$UNIT" == "xumini" ] || [ "$UNIT" == "rppocket" ]; then')
    a = 'if [ "$UNIT" == "g350" ]; then\n'
    need(s.count("\n" + a) == 1, "image_setup.sh: g350 patch block anchor not unique")
    s = s.replace("\n" + a, "\n" + UB + a, 1)
    o = '  xumini) UBOOT_OPTIN="uboot-dtb" ;;\n'
    need(o in s, "image_setup.sh: UBOOT_OPTIN xumini line not found")
    s = s.replace(o, o + '  rppocket) UBOOT_OPTIN="uboot-dtb" ;;\n', 1)
    return s
edit("image_setup.sh", image)

# --- unit list ----------------------------------------------------------------
def units(s):
    if re.search(r"^rppocket$", s, re.M):
        return s
    return s + ("" if s.endswith("\n") else "\n") + "rppocket\n"
edit(".github/units.txt", units)
PY
echo "Done. Review with: git diff"
