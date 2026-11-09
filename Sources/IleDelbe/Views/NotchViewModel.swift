import IleDelbeCore
import Observation

@MainActor @Observable
final class NotchViewModel {
    var isOpen = false
    var geometry: NotchGeometry?
    let nowPlaying: NowPlayingService
    let volume: VolumeService

    init(nowPlaying: NowPlayingService, volume: VolumeService) {
        self.nowPlaying = nowPlaying
        self.volume = volume
    }
}
