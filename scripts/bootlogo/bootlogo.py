#!/usr/bin/python3 -I
# Redraw /boot/logo.bmp (the logo U-Boot shows) on the framebuffer the console blanked.
# tty1 output (firstboot's dialog, mount-spruce's messages) or the frontend's first frame replaces it.
#   bootlogo.py [--check]    --check converts and times it but leaves the screen alone
import fcntl
import struct
import sys
import time

LOGO, FB = "/boot/logo.bmp", "/dev/fb0"
FBIOGET_VSCREENINFO = 0x4600


def main(check):
    t0 = time.monotonic()
    with open(LOGO, "rb") as f:
        bmp = f.read()
    off, = struct.unpack_from("<I", bmp, 10)
    bw, bh = struct.unpack_from("<ii", bmp, 18)
    bits, comp = struct.unpack_from("<HI", bmp, 28)
    with open("/sys/class/graphics/fb0/stride") as f:
        stride = int(f.read())
    with open(FB, "r+b", buffering=0) as fb:
        v = fcntl.ioctl(fb, FBIOGET_VSCREENINFO, bytes(160))
        xres, yres, _, _, xoff, yoff, bpp = struct.unpack_from("7I", v)
        rgb = tuple(struct.unpack_from("I", v, 32 + 12 * i)[0] for i in range(3))
        # Only the plain case: an uncompressed 24-bit BMP the size of the screen, onto XRGB8888.
        if (bmp[:2] != b"BM" or bits != 24 or comp != 0 or (bw, abs(bh)) != (xres, yres)
                or bpp != 32 or rgb != (16, 8, 0) or xoff != 0 or stride < xres * 4):
            print(f"bootlogo: skipped, logo {bw}x{bh}x{bits} vs fb {xres}x{yres}x{bpp} {rgb}", file=sys.stderr)
            return
        row, opaque = (bw * 3 + 3) & ~3, b"\xff" * bw
        out = bytearray(stride * yres)
        for y in range(yres):
            s = off + (yres - 1 - y if bh > 0 else y) * row
            src, o = bmp[s:s + bw * 3], y * stride
            out[o:o + bw * 4:4] = src[0::3]
            out[o + 1:o + bw * 4:4] = src[1::3]
            out[o + 2:o + bw * 4:4] = src[2::3]
            out[o + 3:o + bw * 4:4] = opaque
        if not check:
            fb.seek(yoff * stride)
            fb.write(out)
    print(f"bootlogo: {'checked' if check else 'drew'} {LOGO} in {time.monotonic() - t0:.3f} s", file=sys.stderr)


if __name__ == "__main__":
    try:
        main("--check" in sys.argv[1:])
    except (OSError, ValueError, struct.error) as e:
        print(f"bootlogo: skipped, {e}", file=sys.stderr)
