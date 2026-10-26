# eqMac setup (kept for reference)

eqMac was the first working fix (2026-10-26) and was replaced the same day by Proxy Audio
Device (see the [README](../README.md)). These are the complete eqMac instructions in case the
proxy driver ever misbehaves. Why it works and what its limits are: [discovery §7](discovery.md),
[alternatives](alternatives.md).

**Hard requirement:** the BTR5 must be in **USB 2.0 mode**. eqMac only attenuates in software
when the output device has *no* hardware volume control. In USB 1.0 mode the BTR5 advertises a
volume control that its firmware ignores, eqMac forwards the slider to it, and the volume keys
do nothing while mute still works.

## Switching from Proxy Audio Device to eqMac

Both can be installed at the same time, but only one should be the default output. If you
re-install eqMac, point it at the raw "FiiO BTR5" USB device, never at "FiiO BTR5 (Proxy)",
or the two get chained.

## Install

1. **Put the BTR5 in USB 2.0 mode.** Hold the round button ~2 s, menu `U-AUDIO` → `USB 2.0`,
   then **unplug and replug the USB cable** (the mode only changes on re-enumeration). Verify:

   ```sh
   ioreg -p IOUSB -l -w0 | grep -A12 '+-o FiiO' | grep -E 'bcdDevice|bNumConfigurations'
   # USB 2.0 mode: "bcdDevice" = 46, "bNumConfigurations" = 2  (CoreAudio name "FiiO BTR5")
   # USB 1.0 mode: "bcdDevice" = 47, "bNumConfigurations" = 1  (CoreAudio name "FiiO BTR5 1.1")
   ```

2. **Install eqMac.**

   ```sh
   brew install --cask eqmac
   open -a eqMac          # first launch installs /Library/Audio/Plug-Ins/HAL/eqMac.driver (admin password)
   ```

3. **Route eqMac to the BTR5.** Pick "FiiO BTR5" (the raw USB device) in eqMac's output
   selector, or select that entry in the macOS Sound menu: eqMac takes it as the target and
   re-selects its own "FiiO BTR5 (eqMac)" device as default output within a second.

4. **Send alert sounds through eqMac too.** System Settings › Sound › Sound Effects › *Play
   sound effects through* → "FiiO BTR5 (eqMac)". Or:

   ```sh
   bin/setdefault EQMOutputCapture      # default output AND system-sounds output
   ```

5. **Set the BTR5's own volume once** to a comfortable maximum and use the Mac keys from then on.

6. **Make eqMac start at login** (eqMac settings → *Launch on startup*, or System Settings ›
   General › Login Items). Without it, audio falls back to the raw BTR5 at full volume after a
   reboot. (Unlike the proxy driver, eqMac needs its app running.)

7. **Verify by ear:** `make && tools/test_tones.sh`. `tools/wait_uac2.sh` is the watcher that
   was used when switching the BTR5 back to USB 2.0: it waits for the re-enumeration, re-pins
   `EQMOutputCapture` and runs the tone test.

## Gotchas seen with eqMac

- **Volume keys stop working but mute still works** → the BTR5 is back in USB 1.0 mode.
- eqMac re-grabs the default output when another device is picked, but **does not restore the
  system-sounds output**, so alerts drift to the raw BTR5 at full volume. Redo step 4.
- When the BTR5 re-enumerates, eqMac briefly routes to the **Bluetooth** BTR5 before settling
  on USB. Disconnecting Bluetooth avoids it.
- Its virtual device is named after the target with a trailing-space quirk
  ("FiiO BTR5  (eqMac)", UID `EQMOutputCapture`). Volume range −96…0 dB.
- The current eqMac builds (1.9.x) are a closed private fork; the GitHub repo is Apache-2.0 at
  v1.3.2. Volume/mute are free, EQ extras are "Pro".

## Uninstall

```sh
osascript -e 'tell application "eqMac" to quit'
brew uninstall --cask --zap eqmac      # asks for the sudo password: removes the app, prefs,
                                       # /Library/Audio/Plug-Ins/HAL/eqMac.driver,
                                       # /Library/LaunchDaemons/com.bitgapp.eqmac.helper.plist,
                                       # /Library/PrivilegedHelperTools/com.bitgapp.eqmac.helper
sudo killall coreaudiod
bin/setdefault ProxyAudioDevice_UID    # Core Audio restarts fall back to the Bluetooth BTR5
```

`brew uninstall` needs a real terminal for its sudo prompt; it fails from non-interactive shells.
