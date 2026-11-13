// mic-guard: keep chosen Bluetooth headsets off the system microphone.
//
// A Bluetooth headset whose microphone is in use drops from A2DP (stereo,
// 44.1 kHz) to the hands-free profile (mono, 16 kHz), which hisses. mic-guard
// listens for changes to the default input device and, whenever it becomes a
// device whose name contains one of the given patterns, switches the default
// input to the built-in microphone. Other devices (AirPods, USB mics) are left
// alone.
//
//   mic-guard <pattern>...   watch and redirect (case-insensitive substrings)
//   mic-guard --list         print the input devices and exit

import CoreAudio
import Foundation

let system = AudioObjectID(kAudioObjectSystemObject)

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func log(_ message: String) {
    let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                            formatOptions: [.withInternetDateTime])
    print("\(stamp) \(message)")
}

func defaultInput() -> AudioDeviceID? {
    var addr = address(kAudioHardwarePropertyDefaultInputDevice)
    var id = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id)
    return status == noErr && id != kAudioObjectUnknown ? id : nil
}

func setDefaultInput(_ device: AudioDeviceID) -> OSStatus {
    var addr = address(kAudioHardwarePropertyDefaultInputDevice)
    var id = device
    return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
}

func allDevices() -> [AudioDeviceID] {
    var addr = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

func name(of device: AudioDeviceID) -> String {
    var addr = address(kAudioObjectPropertyName)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr,
          let name = value?.takeRetainedValue() else { return "device \(device)" }
    return name as String
}

func transport(of device: AudioDeviceID) -> UInt32 {
    var addr = address(kAudioDevicePropertyTransportType)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr ? value : 0
}

func hasInput(_ device: AudioDeviceID) -> Bool {
    var addr = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput)
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr && size > 0
}

func builtInMicrophone() -> AudioDeviceID? {
    allDevices().first { transport(of: $0) == kAudioDeviceTransportTypeBuiltIn && hasInput($0) }
}

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--list"] {
    let current = defaultInput()
    for device in allDevices() where hasInput(device) {
        print("\(device == current ? "*" : " ") \(name(of: device))")
    }
    exit(0)
}

guard !arguments.isEmpty, !arguments.contains(where: { $0.hasPrefix("-") }) else {
    FileHandle.standardError.write(Data("usage: mic-guard <device-name-pattern>... | mic-guard --list\n".utf8))
    exit(2)
}

let patterns = arguments.map { $0.lowercased() }
setlinebuf(stdout)

func check() {
    guard let current = defaultInput() else { return }
    let currentName = name(of: current)
    guard patterns.contains(where: { currentName.lowercased().contains($0) }) else { return }
    guard let builtIn = builtInMicrophone() else {
        log("default input is \(currentName), but no built-in microphone was found")
        return
    }
    let status = setDefaultInput(builtIn)
    if status == noErr {
        log("default input was \(currentName), switched to \(name(of: builtIn))")
    } else {
        log("default input is \(currentName), switching to \(name(of: builtIn)) failed (OSStatus \(status))")
    }
}

var listened = address(kAudioHardwarePropertyDefaultInputDevice)
let status = AudioObjectAddPropertyListenerBlock(system, &listened, DispatchQueue.main) { _, _ in check() }
guard status == noErr else {
    log("could not listen for default input changes (OSStatus \(status))")
    exit(1)
}

log("watching for: \(arguments.joined(separator: ", "))")
check()
dispatchMain()
