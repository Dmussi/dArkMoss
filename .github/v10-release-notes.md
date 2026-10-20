
## Powkiddy V10: how to install

The V10 has one SD slot, so dArkMoss and spruce share the same card.

1. **Download** both image parts below (`dArkMoss_V10_..._img.7z.001` and `.002`) into the same folder.
2. **Unpack** with [7-Zip](https://www.7-zip.org/download.html): right-click the `.001` file and choose *Extract Here*. You get one `.img` file.
3. **Flash** the `.img` to your SD card with [balenaEtcher](https://etcher.balena.io/) or Raspberry Pi Imager. This erases the card. If Windows asks to format the disk afterwards, click *Cancel*.
4. **First boot:** put the card in the V10 and turn it on. It sets up the card and makes a **SPRUCEOS** partition (a few minutes), then shows *spruce card not found* and turns off. That is expected.
5. **Copy spruce:** put the card back in your computer and open the **SPRUCEOS** drive.
   - Extract the newest spruce `.7z` into it (a [release](https://github.com/spruceUI/spruceOS/releases) or a [nightly](https://github.com/spruceUI/spruceOSNightlies/releases) with V10 support). If this release carries `spruce-V10-overlay.zip`, see the note below.
6. **Turn the V10 on.** The first start unpacks spruce's apps and themes, which takes a few minutes once.

**Controls:** there is no menu button, so **SELECT + START** opens the menu. In games, SELECT is the hotkey: SELECT+R1 save, SELECT+L1 load, SELECT+Y RetroArch menu, SELECT+B exit.

**Reporting problems:** logs are on the SPRUCEOS drive in `Saves/spruce/` (`spruce.log`, `darkmoss_debug.log`).
