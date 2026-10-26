# Alternatives: virtual output devices with software volume

Assessed 2026-10-26. The requirement: a virtual output device that applies volume and mute to
the samples **itself** and forwards them to the BTR5, without relying on the BTR5's hardware
volume control (which the firmware ignores, see [discovery](discovery.md)).

| | License / cost | Software volume? | Verdict |
| --- | --- | --- | --- |
| **eqMac 1.9.2** | Volume/mute free; "Pro" extras paid. GitHub repo is Apache-2.0 but frozen at v1.3.2; current builds come from a private fork. | **Only when the target device has no hardware volume control.** Otherwise it forwards volume to the hardware. | Worked with the BTR5 in USB 2.0 mode. Used 2026-10-26 until replaced by Proxy Audio Device the same day; uninstalled. |
| **Proxy Audio Device 1.1.0.1** | Unlicense (public domain) | **Always.** The driver multiplies samples by its own volume/mute controls and never touches the target's hardware volume. | **Current setup.** Verified by ear with eqMac quit; works in either BTR5 mode. Device renamed "FiiO BTR5 (Proxy)". |
| **Background Music 0.5.0** | GPL-2.0 | **Never** for the main device, by design: it passes volume through to the real device's control. | Cannot work. Tried and removed. |
| **SoundSource 6.1.5** | Proprietary, paid one-time license (trial available) | Yes, for any output. | Works per vendor claims, not open source. Not tried. |

## eqMac

- https://github.com/bitgapp/eqMac, `brew install --cask eqmac`.
- Mechanics: `Volume.swift` → `gain` setter uses `device.outputVolumeSupported`
  (`virtualMasterVolume(direction: .playback) != nil`) to decide between hardware passthrough
  and `AVAudioMixerNode.outputVolume`. Mute is always `mixer.outputVolume = 0`.
- Consequences for the BTR5: must stay in USB 2.0 mode. In USB 1.0 mode volume keys do nothing
  while mute works.
- Also: a full menu-bar app with EQ, launch-at-login via SMAppService, re-selects its own
  device as default output when another one is picked, but does not restore the system-sounds
  output. Removed on 2026-10-26 in favour of Proxy Audio Device (brew cask `--zap` plus manual
  deletion of its HAL driver, LaunchDaemon plist and privileged helper).

## Proxy Audio Device

- https://github.com/briankendall/proxy-audio-device, `brew install --cask proxy-audio-device`
  (installs `/Library/Audio/Plug-Ins/HAL/ProxyAudioDevice.driver` and a "Proxy Audio Device
  Settings" app, needs an admin password). v1.1.0.1 (2026-10-18) is notarized and fixes a
  long-standing audio-cutout bug; it also adds a "hide when unavailable" setting.
- Mechanics (`proxyAudioDevice/ProxyAudioDevice.cpp`): `calculateVolumeFactors` maps the
  device's own volume control to a gain (0 → silent, 1 → unity, in between
  `10^((v·25 − 25)/10)`, mute → 0) and the IO loop does
  `*out += *in * volumeFactor`. The source never reads or sets the target device's volume.
- Configuration: pick the target device and buffer size in the settings app; too small a buffer
  causes pops/crackle.
- Known issues relevant here: alert sounds at full volume after device changes (#48, same
  system-sounds drift as eqMac); an open PR to re-find devices after USB replugs (#71); a Tahoe
  "no audio" report closed as unrelated (#69).
- **Install gotcha (2026-10-26):** the brew cask needs sudo to place the driver in
  `/Library/Audio/Plug-Ins/HAL`; if that step is retried after a manual copy, brew nests a second
  `ProxyAudioDevice.driver` inside the first and `codesign --verify` reports "unsealed contents
  present in the bundle root", so coreaudiod silently refuses to load it (no "Core Audio Driver
  (ProxyAudioDevice.driver)" process). Fix: keep exactly one signed bundle at that path, then
  `sudo killall coreaudiod` (`launchctl kickstart` was refused by SIP here).
- Tested standalone with eqMac quit: `bin/padctl set-output <BTR5 USB UID>`,
  `bin/setdefault ProxyAudioDevice_UID`, `tools/test_tones.sh`. Routing confirmed (USB BTR5
  streaming, Bluetooth idle); the proxy device exposes per-channel volume (−25…0 dB) and mute.
  Default target after install was the *Bluetooth* BTR5 (it copies the current default output).
- Switching from eqMac (done 2026-10-26): quit eqMac; with admin rights remove
  `/Library/Audio/Plug-Ins/HAL/eqMac.driver`, `/Library/LaunchDaemons/com.bitgapp.eqmac.helper.plist`
  and `/Library/PrivilegedHelperTools/com.bitgapp.eqmac.helper`, then `killall coreaudiod`;
  `brew uninstall --cask --zap eqmac`; re-pin the proxy device with
  `bin/setdefault ProxyAudioDevice_UID` (Core Audio restarts fall back to the Bluetooth BTR5).
- Configuration protocol (what `bin/padctl` implements): the driver's Box object
  (UID `ProxyAudioBox_UID`) is the command channel. Setting `kAudioObjectPropertyIdentify` to the
  caller's pid registers it as configurator; setting it to `-(ConfigType)` makes the next read of
  the box's Name return that setting; setting the box's Name to `key=value`
  (`outputDevice`, `deviceName`, `outputDeviceBufferFrameSize`, `outputDeviceActiveCondition`,
  `outputDeviceHideWhenUnavailable`) changes it, persisted in Core Audio plug-in storage.

## Background Music

- https://github.com/kyleneideck/BackgroundMusic. Tried; all three test beeps audible including
  the muted one ([evidence 04](../evidence/04-background-music-installed-state.txt)).
- `BGMDriver/BGMDriver/BGM_Device.cpp`: the main device "doesn't apply volume to its audio
  because BGMApp changes the real output device's volume directly".
  `BGMApp/BGMApp/BGMDeviceControlsList.cpp` disables BGMDevice's controls when the output has
  none. Open requests since 2018: #176, #153, #196, #518, #866.
- Its uninstaller leaves the `_BGMXPCHelper` system user behind
  (`sudo dscl . -delete /Users/_BGMXPCHelper`).

## SoundSource

- https://rogueamoeba.com/soundsource/. Proprietary. Explicitly supports macOS 27 and advertises
  making the volume keys work with "any outputs you have" (HDMI, DisplayPort, …). Fallback if
  both open options misbehave.

## Others that came up

- **SoundMax**: open-source system EQ with a software volume slider, but requires BlackHole as a
  second driver. More moving parts for the same result.
- **BlackHole**, **FineTune**, **Fabar**: routing or per-app volume tools; none provide
  device-level software volume on their own.
