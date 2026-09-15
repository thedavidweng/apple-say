import AVFAudio
import CoreAudio
import Foundation

@MainActor final class TimelinePlayback {
    private var player: AVAudioPlayer?

    func play(_ url: URL, device: String?) async throws {
        let player = try AVAudioPlayer(contentsOf: url)
        if let device, let id = UInt32(device) {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var uid: CFString = "" as CFString
            var size = UInt32(MemoryLayout<CFString>.size)
            let status = withUnsafeMutablePointer(to: &uid) {
                AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
            }
            guard status == noErr else { throw SpeechError.invalidSettings("The audio output device is unavailable.") }
            player.currentDevice = uid as String
        }
        self.player = player
        defer { player.stop(); self.player = nil }
        guard player.play() else { throw SpeechError.processFailed("The system could not start Preview.") }
        while player.isPlaying { try await Task.sleep(for: .milliseconds(20)) }
        try Task.checkCancellation()
    }

    func stop() { player?.stop() }
}
