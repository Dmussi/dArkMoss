#!/bin/sh
# "Loading..." on the blank console, centred on the row where the boot logo's status line will be
# (the second-last of 8x16 cells), until bootlogo.py draws the logo (and clears this text).
set -- $(stty -F /dev/tty1 size 2>/dev/null)
printf '\033[%d;%dHLoading...' "$(( ${1:-30} - 1 ))" "$(( (${2:-80} - 10) / 2 + 1 ))" > /dev/tty1
