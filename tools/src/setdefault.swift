import CoreAudio
import Foundation
// usage: setdefault <device UID>  — sets both the default output and the system-sounds output
let wantUID = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppleUSBAudioEngine:FiiO:FiiO BTR5:1100000:1"
let sys = AudioObjectID(kAudioObjectSystemObject)
var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
var sz: UInt32 = 0; AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &sz)
var devs = [AudioObjectID](repeating: 0, count: Int(sz)/4); AudioObjectGetPropertyData(sys, &a, 0, nil, &sz, &devs)
var target: AudioObjectID = 0
for d in devs {
    var ua = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
    var usz = UInt32(MemoryLayout<CFString?>.size); var s: CFString? = nil
    _ = withUnsafeMutablePointer(to: &s) { AudioObjectGetPropertyData(d, &ua, 0, nil, &usz, $0) }
    if (s as String?) == wantUID { target = d }
}
guard target != 0 else { print("device with UID \(wantUID) not found"); exit(1) }
for sel in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
    var da = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
    var t = target
    let st = AudioObjectSetPropertyData(sys, &da, 0, nil, UInt32(4), &t)
    print("set \(sel == kAudioHardwarePropertyDefaultOutputDevice ? "default output" : "system output") -> id \(target): \(st == noErr ? "ok" : "error \(st)")")
}
