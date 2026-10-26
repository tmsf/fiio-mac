import CoreAudio
import AudioToolbox
import Foundation

func prop(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ elem: UInt32) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: elem)
}
func has(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ elem: UInt32) -> Bool {
    var a = prop(dev, sel, scope, elem); return AudioObjectHasProperty(dev, &a)
}
func settable(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ elem: UInt32) -> Bool {
    var a = prop(dev, sel, scope, elem); var s: DarwinBoolean = false
    return AudioObjectIsPropertySettable(dev, &a, &s) == noErr && s.boolValue
}
func str(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String {
    var a = prop(dev, sel, kAudioObjectPropertyScopeGlobal, 0)
    var size = UInt32(MemoryLayout<CFString?>.size); var s: CFString? = nil
    let st = withUnsafeMutablePointer(to: &s) { AudioObjectGetPropertyData(dev, &a, 0, nil, &size, $0) }
    return st == noErr ? (s! as String) : "?"
}
func u32(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32 {
    var a = prop(dev, sel, scope, 0); var size = UInt32(4); var v: UInt32 = 0
    AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &v); return v
}
func f32(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ elem: UInt32) -> Float32 {
    var a = prop(dev, sel, scope, elem); var size = UInt32(4); var v: Float32 = -1
    AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &v); return v
}
func fourcc(_ v: UInt32) -> String {
    let b = [UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 8) & 0xff), UInt8(v & 0xff)]
    return String(bytes: b, encoding: .macOSRoman) ?? "????"
}

// enumerate devices
var addr = prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, 0)
var size: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
var devs = [AudioObjectID](repeating: 0, count: Int(size) / 4)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devs)

let out = kAudioObjectPropertyScopeOutput
for d in devs {
    let name = str(d, kAudioObjectPropertyName)
    let uid = str(d, kAudioDevicePropertyDeviceUID)
    let transport = fourcc(u32(d, kAudioDevicePropertyTransportType))
    // output channel count
    var sa = prop(d, kAudioDevicePropertyStreamConfiguration, out, 0); var ssize: UInt32 = 0
    AudioObjectGetPropertyDataSize(d, &sa, 0, nil, &ssize)
    if ssize == 0 { continue }
    let buf = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(ssize)); defer { buf.deallocate() }
    AudioObjectGetPropertyData(d, &sa, 0, nil, &ssize, buf)
    let abl = UnsafeMutableAudioBufferListPointer(buf)
    let chans = abl.reduce(0) { $0 + Int($1.mNumberChannels) }
    if chans == 0 { continue }
    print("== \(name) [\(transport)] id=\(d) uid=\(uid) outChans=\(chans)")
    print("   VirtualMainVolume: has=\(has(d, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, out, 0)) settable=\(settable(d, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, out, 0)) val=\(f32(d, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, out, 0))")
    for ch in 0...UInt32(chans) {
        let hv = has(d, kAudioDevicePropertyVolumeScalar, out, ch)
        let hm = has(d, kAudioDevicePropertyMute, out, ch)
        let hdb = has(d, kAudioDevicePropertyVolumeDecibels, out, ch)
        if hv || hm || hdb {
            print("   ch\(ch): volumeScalar has=\(hv) settable=\(settable(d, kAudioDevicePropertyVolumeScalar, out, ch)) val=\(f32(d, kAudioDevicePropertyVolumeScalar, out, ch)) | dB has=\(hdb) | mute has=\(hm) settable=\(settable(d, kAudioDevicePropertyMute, out, ch))")
        } else {
            print("   ch\(ch): no volume / mute / dB controls")
        }
    }
    // other controls that might exist
    var ca = prop(d, kAudioObjectPropertyControlList, kAudioObjectPropertyScopeGlobal, 0); var csize: UInt32 = 0
    AudioObjectGetPropertyDataSize(d, &ca, 0, nil, &csize)
    var ctrls = [AudioObjectID](repeating: 0, count: Int(csize) / 4)
    if csize > 0 { AudioObjectGetPropertyData(d, &ca, 0, nil, &csize, &ctrls) }
    var descs: [String] = []
    for c in ctrls {
        let cls = fourcc(u32(c, kAudioObjectPropertyClass))
        let scope = fourcc(u32(c, kAudioControlPropertyScope))
        let el = u32(c, kAudioControlPropertyElement)
        descs.append("\(cls)/\(scope)/el\(el)")
    }
    print("   control objects (\(ctrls.count)): \(descs.joined(separator: ", "))")
}
