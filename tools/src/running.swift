import CoreAudio
import AudioToolbox
import Foundation
func addr(_ s: AudioObjectPropertySelector, _ sc: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ e: UInt32 = 0) -> AudioObjectPropertyAddress { AudioObjectPropertyAddress(mSelector: s, mScope: sc, mElement: e) }
func getU32(_ d: AudioObjectID, _ a: AudioObjectPropertyAddress) -> UInt32 { var a = a; var sz = UInt32(4); var v: UInt32 = 0; AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &v); return v }
func getF32(_ d: AudioObjectID, _ a: AudioObjectPropertyAddress) -> Float32 { var a = a; var sz = UInt32(4); var v: Float32 = .nan; AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &v); return v }
func name(_ d: AudioObjectID) -> String { var a = addr(kAudioObjectPropertyName); var sz = UInt32(MemoryLayout<CFString?>.size); var s: CFString? = nil; _ = withUnsafeMutablePointer(to: &s) { AudioObjectGetPropertyData(d, &a, 0, nil, &sz, $0) }; return (s as String?) ?? "?" }
func fourcc(_ v: UInt32) -> String { String(bytes: [UInt8(v>>24&0xff),UInt8(v>>16&0xff),UInt8(v>>8&0xff),UInt8(v&0xff)], encoding: .macOSRoman) ?? "????" }
let sys = AudioObjectID(kAudioObjectSystemObject)
let defOut = getU32(sys, addr(kAudioHardwarePropertyDefaultOutputDevice))
let defSys = getU32(sys, addr(kAudioHardwarePropertyDefaultSystemOutputDevice))
print("default output id=\(defOut) '\(name(defOut))'   system-sounds output id=\(defSys) '\(name(defSys))'")
var a = addr(kAudioHardwarePropertyDevices); var sz: UInt32 = 0
AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &sz)
var devs = [AudioObjectID](repeating: 0, count: Int(sz)/4); AudioObjectGetPropertyData(sys, &a, 0, nil, &sz, &devs)
let out = kAudioObjectPropertyScopeOutput
for d in devs {
    var sa = addr(kAudioDevicePropertyStreamConfiguration, out); var ssz: UInt32 = 0
    AudioObjectGetPropertyDataSize(d, &sa, 0, nil, &ssz); if ssz == 0 { continue }
    let buf = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(ssz)); defer { buf.deallocate() }
    AudioObjectGetPropertyData(d, &sa, 0, nil, &ssz, buf)
    if UnsafeMutableAudioBufferListPointer(buf).reduce(0, { $0 + Int($1.mNumberChannels) }) == 0 { continue }
    let running = getU32(d, addr(kAudioDevicePropertyDeviceIsRunningSomewhere))
    let transport = fourcc(getU32(d, addr(kAudioDevicePropertyTransportType)))
    var line = "  id=\(d) [\(transport)] '\(name(d))' runningSomewhere=\(running)"
    var va = addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, out)
    if AudioObjectHasProperty(d, &va) {
        line += "  mainVol=\(getF32(d, va))"
        for ch in UInt32(0)...2 {
            var ra = addr(kAudioDevicePropertyVolumeRangeDecibels, out, ch)
            if AudioObjectHasProperty(d, &ra) {
                var r = AudioValueRange(); var rsz = UInt32(MemoryLayout<AudioValueRange>.size)
                AudioObjectGetPropertyData(d, &ra, 0, nil, &rsz, &r)
                line += "  ch\(ch): \(getF32(d, addr(kAudioDevicePropertyVolumeDecibels, out, ch))) dB (range \(r.mMinimum)…\(r.mMaximum) dB) mute=\(getU32(d, addr(kAudioDevicePropertyMute, out, ch)))"
            }
        }
    }
    print(line)
}
