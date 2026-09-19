import CoreAudio
import CoreMediaIO

/// Detects whether any app is using the microphone or camera.
/// It only reads the "is running somewhere" flag of each device, so it never
/// records audio or video and does not trigger a permission prompt.
struct CallDetector {

    /// CoreMediaIO did not get the `Master` -> `Main` rename that CoreAudio got in
    /// macOS 12, and the spelling differs across SDKs. The value is 0 in every version.
    private let cmioElementMain = CMIOObjectPropertyElement(0)

    // MARK: Microphone

    func isMicrophoneInUse() -> Bool {
        audioDeviceIDs().contains { device in
            hasInputStreams(device) && !isVirtualOrAggregate(device) && isRunningSomewhere(device)
        }
    }

    private func audioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }

        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func hasInputStreams(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    /// Virtual devices (for example, meeting app audio drivers) can report as running
    /// even when no one is talking, so they are skipped.
    private func isVirtualOrAggregate(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport) == noErr else { return false }
        return transport == kAudioDeviceTransportTypeVirtual || transport == kAudioDeviceTransportTypeAggregate
    }

    private func isRunningSomewhere(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    // MARK: Camera

    func isCameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: cmioElementMain
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else { return false }

        var devices = [CMIOObjectID](repeating: 0, count: Int(dataSize) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, dataSize, &used, &devices) == noErr else { return false }

        return devices.contains { device in
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: cmioElementMain
            )
            var running: UInt32 = 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            var usedSize: UInt32 = 0
            let status = CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, size, &usedSize, &running)
            return status == noErr && running != 0
        }
    }
}
