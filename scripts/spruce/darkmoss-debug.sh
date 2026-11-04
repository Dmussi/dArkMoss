#!/bin/sh
# Export readable logs to the boot partition, where a PC can get at them.
#
# Off unless /boot/darkmoss-debug exists. /boot is the FAT partition labelled
# dArkMoss - the only thing on TF1 a Windows or Mac machine can read - so
# turning this on is "create an empty file on the card", and reading the result
# back is "look in /boot/logs". No SSH, no btrfs driver, no second device.
#
# The journal itself is always persistent (journald.conf, 64M cap); this only
# makes it legible off the card. Keeping the /boot writes behind a flag is
# deliberate: an unclean poweroff can dirty that FAT partition, and unlike a
# dirty data partition a dirty /boot is a device that does not boot. Users who
# have not asked for logs never take that risk.
#
# To add a collector, add a line in the block marked below. One file each, keep
# it cheap and non-blocking - this runs on every boot the flag is set.

FLAG=/boot/darkmoss-debug
LOGDIR=/boot/logs
KEEP=5

[ -e "$FLAG" ] || exit 0
mountpoint -q /boot || exit 0

STAMP=$(date +%Y%m%d-%H%M%S 2>/dev/null) || STAMP=unknown
OUT="$LOGDIR/$STAMP"
mkdir -p "$OUT" || exit 0

# The previous boot is usually the interesting one: you reproduce the fault,
# power cycle, and read it here. -b 0 covers anything that has already gone
# wrong this boot.
journalctl -b -1 --no-pager > "$OUT/previous-boot.log" 2>/dev/null
journalctl -b 0 --no-pager  > "$OUT/this-boot.log"     2>/dev/null
dmesg                       > "$OUT/dmesg.log"         2>/dev/null

{
    echo "date:    $(date 2>/dev/null)"
    echo "kernel:  $(uname -a 2>/dev/null)"
    echo "uptime:  $(uptime 2>/dev/null)"
    echo
    echo "--- mounts"
    mount
    echo
    echo "--- disk"
    df -h
    echo
    echo "--- failed units"
    systemctl --failed --no-pager 2>/dev/null
} > "$OUT/system.txt" 2>/dev/null

# spruce keeps its own log on TF2. Copy it if the card is up by the time we run.
if [ -f /mnt/SDCARD/Saves/spruce/spruce.log ]; then
    cp -f /mnt/SDCARD/Saves/spruce/spruce.log "$OUT/spruce.log" 2>/dev/null
fi

# --- add further collectors here -------------------------------------------

# Hardware state for display and power bring-up. Answers "which rail or gate is
# off" from a single boot, without a shell on the device. debugfs is mounted by
# systemd; mount it if something has not.
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null
{
    echo "--- device tree model"
    tr -d '\0' < /proc/device-tree/model 2>/dev/null; echo
    echo
    echo "--- cmdline"
    cat /proc/cmdline 2>/dev/null
    echo
    echo "--- gpio (look for lcd-vspn-en, lcd-vcc5v-en, amp-en, wifi-3v3-en: all should be out hi)"
    cat /sys/kernel/debug/gpio 2>/dev/null
    echo
    echo "--- regulators"
    cat /sys/kernel/debug/regulator/regulator_summary 2>/dev/null
    echo
    echo "--- backlight"
    for b in /sys/class/backlight/*; do
        [ -d "$b" ] || continue
        echo "$b"
        for f in brightness actual_brightness max_brightness bl_power; do
            [ -r "$b/$f" ] && echo "  $f: $(cat "$b/$f" 2>/dev/null)"
        done
    done
    echo
    echo "--- pwm"
    cat /sys/kernel/debug/pwm 2>/dev/null
    echo
    echo "--- pin claims for the panel pins (pinctrl)"
    cat /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins 2>/dev/null | grep -E "pin (2|3|8|9|10|11|20|21|22|23|24|25|112|115|117|120|128|129) " 
    echo
    echo "--- drm"
    for c in /sys/class/drm/card*-*; do
        [ -d "$c" ] || continue
        echo "$c status=$(cat "$c/status" 2>/dev/null) enabled=$(cat "$c/enabled" 2>/dev/null) modes=$(tr '\n' ' ' < "$c/modes" 2>/dev/null)"
    done
    echo
    echo "--- drm state"
    cat /sys/kernel/debug/dri/0/state 2>/dev/null | head -n 80
    echo
    echo "--- framebuffer"
    cat /sys/class/graphics/fb0/virtual_size 2>/dev/null
    cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null
    echo
    echo "--- fbcon / vtconsole"
    for v in /sys/class/vtconsole/vtcon*; do
        [ -d "$v" ] && echo "$v: $(cat "$v/name" 2>/dev/null) bind=$(cat "$v/bind" 2>/dev/null)"
    done
} > "$OUT/hw-state.txt" 2>&1

# Keep the newest $KEEP runs. /boot is 104MB and a dirty one is a brick, so
# this is not optional housekeeping.
ls -1d "$LOGDIR"/*/ 2>/dev/null | sort | head -n "-$KEEP" | while read -r old; do
    rm -rf "$old"
done

sync
