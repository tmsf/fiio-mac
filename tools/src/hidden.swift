import CoreAudio
import Foundation
func fourcc(_ s: String) -> String { let n = s.utf8.count; return n == 4 ? s : s }
var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var size: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)
for id in ids {
  var uidAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  var uid: CFString? = nil; var s = UInt32(MemoryLayout<CFString?>.size)
  _ = withUnsafeMutablePointer(to: &uid) { AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &s, $0) }
  let u = (uid as String?) ?? ""
  guard u.contains("FiiO") || u.contains("EQM") else { continue }
  var hAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyIsHidden, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  let has = AudioObjectHasProperty(id, &hAddr)
  var settable: DarwinBoolean = false
  let st = AudioObjectIsPropertySettable(id, &hAddr, &settable)
  var val: UInt32 = 0; var vs = UInt32(4)
  let gst = AudioObjectGetPropertyData(id, &hAddr, 0, nil, &vs, &val)
  var one: UInt32 = 1
  let sst = AudioObjectSetPropertyData(id, &hAddr, 0, nil, 4, &one)
  func e(_ x: OSStatus) -> String { if x == 0 { return "ok" }; var be = UInt32(bitPattern: x).bigEndian; let d = Data(bytes: &be, count: 4); return "'\(String(data: d, encoding: .ascii) ?? "?")' (\(x))" }
  print("id=\(id) uid=\(u)")
  print("   IsHidden: has=\(has) settable=\(settable.boolValue) [\(e(st))] value=\(val) [\(e(gst))]  set-attempt=\(e(sst))")
}
