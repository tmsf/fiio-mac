// padctl — configure Proxy Audio Device (github.com/briankendall/proxy-audio-device) from the shell.
//
// Speaks the same protocol as the bundled "Proxy Audio Device Settings" app: the driver's Box
// object (UID "ProxyAudioBox_UID") is the command channel. Setting kAudioObjectPropertyIdentify
// to this process's pid registers it as configurator; setting it to -(ConfigType) selects which
// value a subsequent read of the box's Name returns; setting the box's Name to "key=value"
// changes a setting (the driver persists it in CoreAudio plug-in storage).
//
// usage: padctl status
//        padctl set-output <device UID>      e.g. 'AppleUSBAudioEngine:FiiO:FiiO BTR5:1100000:1'
//        padctl set-buffer <frames>          default 512, min 4
//        padctl set-name <name>              CoreAudio name of the proxy device
//        padctl set-active <0|1|2>           0=when proxied device active, 1=when user active (default), 2=always
//        padctl set-hide <0|1>               hide proxy device when the target is unavailable
import CoreAudio
import Foundation

enum ConfigType: Int32 { case none = 0, outputDevice, bufferFrameSize, deviceName, activeCondition, hideWhenUnavailable }

func addr(_ s: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
  AudioObjectPropertyAddress(mSelector: s, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}
func objectForUID(_ uid: String, _ selector: AudioObjectPropertySelector) -> AudioObjectID {
  var a = addr(selector)
  var cf: CFString? = uid as CFString
  var out: AudioObjectID = kAudioObjectUnknown
  var sz = UInt32(MemoryLayout<AudioObjectID>.size)
  let st = withUnsafeMutablePointer(to: &cf) { p in
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, UInt32(MemoryLayout<CFString?>.size), p, &sz, &out)
  }
  return st == noErr ? out : kAudioObjectUnknown
}
func name(_ id: AudioObjectID) -> String? {
  var a = addr(kAudioObjectPropertyName)
  var cf: CFString? = nil
  var sz = UInt32(MemoryLayout<CFString?>.size)
  let st = withUnsafeMutablePointer(to: &cf) { AudioObjectGetPropertyData(id, &a, 0, nil, &sz, $0) }
  return st == noErr ? (cf as String?) : nil
}
func setName(_ id: AudioObjectID, _ value: String) -> OSStatus {
  var a = addr(kAudioObjectPropertyName)
  var cf: CFString? = value as CFString
  return withUnsafeMutablePointer(to: &cf) { AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<CFString?>.size), $0) }
}
func setIdentify(_ id: AudioObjectID, _ value: Int32) -> OSStatus {
  var a = addr(kAudioObjectPropertyIdentify)
  var v = value
  return AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Int32>.size), &v)
}
func query(_ box: AudioObjectID, _ t: ConfigType) -> String {
  _ = setIdentify(box, -t.rawValue)
  return name(box) ?? "<unreadable>"
}
func deviceName(forUID uid: String) -> String {
  let d = objectForUID(uid, kAudioHardwarePropertyTranslateUIDToDevice)
  return d == kAudioObjectUnknown ? "<not present>" : (name(d) ?? "?")
}

let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: padctl status | set-output <UID> | set-buffer <n> | set-name <name> | set-active <0|1|2> | set-hide <0|1>"); exit(2) }

let box = objectForUID("ProxyAudioBox_UID", kAudioHardwarePropertyTranslateUIDToBox)
guard box != kAudioObjectUnknown else { print("Proxy Audio Device box not found: driver not loaded (is ProxyAudioDevice.driver in /Library/Audio/Plug-Ins/HAL and was coreaudiod restarted?)"); exit(1) }
let reg = setIdentify(box, Int32(getpid()))
guard reg == noErr else { print("could not register as configurator (status \(reg))"); exit(1) }

func status() {
  let dev = objectForUID("ProxyAudioDevice_UID", kAudioHardwarePropertyTranslateUIDToDevice)
  print("box id=\(box)   proxy device id=\(dev == kAudioObjectUnknown ? "<not published>" : String(dev))")
  print("deviceName:          \(query(box, .deviceName))")
  let out = query(box, .outputDevice)
  print("outputDevice UID:    \(out)   -> \(deviceName(forUID: out))")
  print("bufferFrameSize:     \(query(box, .bufferFrameSize))")
  let ac = query(box, .activeCondition)
  print("activeCondition:     \(ac)   (0=proxied device active, 1=user active, 2=always)")
  print("hideWhenUnavailable: \(query(box, .hideWhenUnavailable))")
}
func set(_ key: String, _ value: String) {
  let st = setName(box, "\(key)=\(value)")
  print(st == noErr ? "set \(key)=\(value): ok" : "set \(key) failed (status \(st))")
  usleep(300_000)
  status()
}

switch args[1] {
case "status": status()
case "set-output" where args.count > 2: set("outputDevice", args[2])
case "set-buffer" where args.count > 2: set("outputDeviceBufferFrameSize", args[2])
case "set-name"   where args.count > 2: set("deviceName", args[2])
case "set-active" where args.count > 2: set("outputDeviceActiveCondition", args[2])
case "set-hide"   where args.count > 2: set("outputDeviceHideWhenUnavailable", args[2])
default: print("unknown or incomplete command: \(args.dropFirst().joined(separator: " "))"); exit(2)
}
