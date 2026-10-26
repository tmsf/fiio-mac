# fiio-mac

Making the Mac's volume keys (and mute) work for a **FiiO BTR5** used as a USB DAC.

Out of the box macOS shows no volume slider for the BTR5 over USB, and in the one USB mode
where it does show one, the slider does nothing. This repo holds the working setup, the
how-to, the full investigation and the small CoreAudio/IOKit probes written along the way.

## TL;DR

- The BTR5 firmware **ignores host volume over USB in both of its USB modes**. This is by
  design (FiiO's FAQ says to set the computer to max and use the device buttons).
- The fix is a **software gain stage in front of the USB stream**: a virtual output device
  that applies volume/mute to the samples and forwards them to the BTR5.
- Setup in use: **[Proxy Audio Device](https://github.com/briankendall/proxy-audio-device)**
  (open source, public domain), a HAL driver that always attenuates in software, renamed to
  "FiiO BTR5 (Proxy)". Works in either BTR5 USB mode; nothing runs at login except the driver
  inside Core Audio.
- Also works: **eqMac**, but only with the BTR5 in USB 2.0 mode, and the current builds are
  closed source. Full eqMac instructions kept in [docs/eqmac-setup.md](docs/eqmac-setup.md).
  **Background Music cannot work** for this. Comparison: [docs/alternatives.md](docs/alternatives.md).

Details and evidence: [docs/discovery.md](docs/discovery.md).

## Setup (how-to)

Tested on macOS 27.0.1 (build 26A434), Apple Silicon MacBook Pro, Proxy Audio Device 1.1.0.1,
BTR5 USB id `2972:0047`.

1. **Build the helper tools** (Xcode Command Line Tools required):

   ```sh
   make
   ```

2. **Install Proxy Audio Device.**

   ```sh
   brew install --cask proxy-audio-device
   ```

   The cask needs your password to put `ProxyAudioDevice.driver` into
   `/Library/Audio/Plug-Ins/HAL` and restart Core Audio. Check it really loaded:

   ```sh
   codesign --verify --deep --strict -v /Library/Audio/Plug-Ins/HAL/ProxyAudioDevice.driver   # must say "valid on disk"
   pgrep -fl 'Core Audio Driver (ProxyAudioDevice'                                          # driver host process
   bin/padctl status                                                                        # finds the box + device
   ```

   If the first command complains about "unsealed contents present in the bundle root", the
   bundle got nested or polluted (it happened here when brew's install was retried after a manual
   copy). Keep exactly one signed `ProxyAudioDevice.driver` at that path, then
   `sudo killall coreaudiod`.

3. **Point it at the BTR5 and name it.** The driver defaults to whatever was the default output
   at install time (here: the *Bluetooth* BTR5), so set it explicitly:

   ```sh
   bin/padctl set-output 'AppleUSBAudioEngine:FiiO:FiiO BTR5:1100000:1'   # UID from bin/audioprops
   bin/padctl set-name 'FiiO BTR5 (Proxy)'
   ```

   (The bundled "Proxy Audio Device Settings" app does the same with a GUI.)

4. **Make it the output for everything, including alert sounds.** Alerts otherwise bypass the
   volume control and play at full BTR5 volume.

   ```sh
   bin/setdefault ProxyAudioDevice_UID      # default output AND system-sounds output
   ```

   GUI equivalent: System Settings › Sound › Output → "FiiO BTR5 (Proxy)", and Sound Effects ›
   *Play sound effects through* → "FiiO BTR5 (Proxy)".

5. **Set the BTR5's own volume once** (device buttons) to a comfortable maximum, then leave it
   alone and use the Mac keys.

6. **Optional:** disconnect the BTR5's Bluetooth while using it over USB (FiiO recommends it).
   macOS falls back to the Bluetooth "FiiO BTR5" whenever Core Audio restarts.

7. **Verify by ear:**

   ```sh
   tools/test_tones.sh     # 60 % tone, 10 % tone, then a muted one you should NOT hear
   ```

The BTR5's USB mode (`U-AUDIO` menu) does not matter for volume with this setup. USB 2.0 is
still the better mode (32-bit, higher rates); USB 1.0 caps at 24-bit/96 kHz.

## Things to know day to day

- **Three "FiiO BTR5" entries in the Sound menu** are expected: Bluetooth, the raw USB device
  "FiiO BTR5", and "FiiO BTR5 (Proxy)". Always pick the Proxy one. The raw one cannot be hidden:
  CoreAudio's `IsHidden` flag is owned by Apple's USB audio driver and is read-only
  (`bin/hidden` demonstrates this). Only the Bluetooth entry can be removed, by disconnecting
  Bluetooth. `bin/padctl set-hide 1` makes the Proxy entry disappear while the BTR5 is unplugged.
- **Sound went quiet or ignores the keys** → Core Audio restarted and macOS fell back to the
  Bluetooth BTR5, or something selected the raw USB device. Run `bin/setdefault
  ProxyAudioDevice_UID` (or pick "FiiO BTR5 (Proxy)" in the Sound menu and fix Sound Effects).
- **Alerts suddenly at full volume** → the system-sounds output drifted to the raw device. Same
  fix as above.
- **Pops or crackle** → raise the buffer: `bin/padctl set-buffer 1024` (default 512).
- **Volume feels coarse at the low end** → the proxy's control spans −25…0 dB and the lowest
  non-muted step is already quiet; that is how the driver maps the slider.
- `bin/running` shows which device is actually streaming (`runningSomewhere=1`); the raw USB
  BTR5 should be the one, with the Proxy device as default output.

## Tools

`make` builds everything into `bin/` (needs Xcode Command Line Tools).

| Tool | What it does |
| --- | --- |
| `bin/padctl` | Configures Proxy Audio Device from the shell: `status`, `set-output <UID>`, `set-name <name>`, `set-buffer <frames>`, `set-active <0|1|2>`, `set-hide <0|1>`. Uses the same box-name protocol as its settings app. |
| `bin/setdefault <UID>` | Sets both the default output and the system-sounds output to the device with that UID (`ProxyAudioDevice_UID` for the proxy). |
| `bin/running` | Default output + system-sounds output, and for every output device: transport, whether it is streaming, main volume, per-channel dB and mute. |
| `bin/audioprops` | Per device: `VirtualMainVolume` presence/settability, per-channel volume/dB/mute controls, full list of control objects (`vlme`, `mute`, `clck`, …) and UIDs. |
| `bin/usbdesc` | Dumps and decodes the BTR5's USB configuration descriptors (UAC1 and UAC2 audio-class descriptors, feature units, formats, endpoints) via IOUSBLib. |
| `bin/usbreenum` | Asks the USB host to re-enumerate the BTR5 (`USBDeviceReEnumerate`). Does **not** switch USB modes, a physical replug is needed for that. |
| `bin/hidden` | Shows that `kAudioDevicePropertyIsHidden` exists but is not settable on the FiiO devices. |
| `tools/test_tones.sh` | The 3-step audible test (60 % / 10 % / muted) through the default output device. |
| `tools/wait_and_probe.sh` | Waits for the BTR5 on USB, then dumps descriptors + CoreAudio controls. |
| `tools/wait_reenum.sh` | Waits for a true re-enumeration (new IORegistry id), then dumps the same. |
| `tools/wait_uac2.sh` | Waits for the BTR5 to come back in USB 2.0 mode, then probes and runs the tone test (written for the eqMac era; re-pins `EQMOutputCapture`). |
| `tools/make_tone.py` | Generates the 4 s / 440 Hz / 48 kHz stereo test tone (`bin/tone.wav`). |

Device UIDs seen on this machine: raw BTR5 `AppleUSBAudioEngine:FiiO:FiiO BTR5:1100000:1`
(the `1100000` part is the USB location id, it changes with the port), proxy
`ProxyAudioDevice_UID`, proxy box `ProxyAudioBox_UID`.

## Repo layout

```
README.md            this file: setup and day-to-day notes
docs/discovery.md    the investigation: root cause, what was tried, why each thing did or did not work
docs/alternatives.md Proxy Audio Device vs eqMac vs Background Music vs SoundSource (licenses, mechanics)
docs/eqmac-setup.md  the previous eqMac setup, kept as a fallback (needs BTR5 in USB 2.0 mode)
evidence/            raw probe output captured during the investigation (descriptor dumps, CoreAudio state)
tools/src/           probe sources (Swift: CoreAudio; C: IOKit/IOUSBLib)
tools/*.sh           watcher and test scripts
Makefile             builds tools into bin/ (gitignored)
```
