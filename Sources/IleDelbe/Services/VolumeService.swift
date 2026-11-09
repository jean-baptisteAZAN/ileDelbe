import AudioToolbox
import CoreAudio
import Observation

/// Exposes the default output device's volume (0...1) and keeps it in sync with the system.
@MainActor @Observable
final class VolumeService {
    private(set) var volume: Float = 0
    private(set) var isSettable: Bool = false

    @ObservationIgnored private var deviceID = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var deviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var volumeListener: AudioObjectPropertyListenerBlock?

    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    init() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.bindToDefaultDevice() }
        }
        deviceListener = listener
        var addr = Self.defaultDeviceAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, listener)
        bindToDefaultDevice()
    }

    func set(_ value: Float) {
        guard isSettable else { return }
        var v = min(max(value, 0), 1)
        var addr = Self.volumeAddress
        let status = AudioObjectSetPropertyData(deviceID, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if status == noErr { volume = v }
    }

    private func bindToDefaultDevice() {
        unbindVolumeListener()
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = Self.defaultDeviceAddress
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        guard status == noErr, id != kAudioObjectUnknown else {
            deviceID = AudioObjectID(kAudioObjectUnknown)
            isSettable = false
            return
        }
        deviceID = id

        var vAddr = Self.volumeAddress
        guard AudioObjectHasProperty(id, &vAddr) else {
            isSettable = false
            return
        }
        var settable: DarwinBoolean = false
        isSettable = AudioObjectIsPropertySettable(id, &vAddr, &settable) == noErr && settable.boolValue
        readVolume()

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.readVolume() }
        }
        volumeListener = listener
        AudioObjectAddPropertyListenerBlock(id, &vAddr, DispatchQueue.main, listener)
    }

    private func unbindVolumeListener() {
        guard let listener = volumeListener, deviceID != kAudioObjectUnknown else {
            volumeListener = nil
            return
        }
        var addr = Self.volumeAddress
        AudioObjectRemovePropertyListenerBlock(deviceID, &addr, DispatchQueue.main, listener)
        volumeListener = nil
    }

    private func readVolume() {
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = Self.volumeAddress
        if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &v) == noErr {
            volume = min(max(v, 0), 1)
        }
    }
}
