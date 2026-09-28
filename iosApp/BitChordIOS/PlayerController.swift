import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI
import GRDB

@MainActor
final class PlayerController: ObservableObject {
    static let shared = PlayerController()
    
    // MARK: - Published State
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var currentIndex: Int = -1
    @Published var history: [Track] = []
    
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var isBuffering = false
    @Published var error: String?
    
    @Published var position: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var bufferedPosition: TimeInterval = 0
    
    @Published var volume: Float = 1.0 {
        didSet { player?.volume = volume }
    }
    
    @Published var playbackSpeed: Float = 1.0 {
        didSet { player?.rate = playbackSpeed }
    }
    
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleMode: ShuffleMode = .off
    @Published var audioQuality: AudioQuality = .high
    
    @Published var crossfadeDuration: TimeInterval = 8.0
    @Published var isCrossfadeEnabled = true
    @Published var isGaplessEnabled = true
    @Published var isAutomixEnabled = false
    @Published var isSkipSilenceEnabled = false
    @Published var isVolumeNormalizationEnabled = false
    
    @Published var wifiQuality: AudioQuality = .high
    @Published var mobileQuality: AudioQuality = .standard
    
    @Published var equalizerPreset: EqualizerPreset = .flat {
        didSet { updateEqualizer() }
    }
    @Published var equalizerBands: [Float] = Array(repeating: 0, count: 10) {
        didSet { updateEqualizerBands() }
    }
    @Published var isEqualizerEnabled = false
    
    @Published var isSpatialAudioEnabled = false
    @Published var isHeadTrackingEnabled = false
    
    @Published var sleepTimerRemaining: TimeInterval?
    private var sleepTimer: Timer?
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var nextPlayer: AVPlayer?
    private var nextPlayerItem: AVPlayerItem?
    private var crossfadeTimer: Timer?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Audio session
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()
    private var mixerNode: AVAudioMixerNode?
    private var equalizerNode: AVAudioUnitEQ?
    private var spatialAudioNode: AVAudioEnvironmentNode?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var isOnWifi = true
    
    // Database
    private let database = LocalDatabase.shared
    
    // Stream resolver (from shared module)
    private var streamResolver: StreamResolver?
    
    private init() {
        setupAudioEngine()
        setupNetworkMonitoring()
        setupNotifications()
        restoreState()
        loadQueueFromDatabase()
    }
    
    // MARK: - Public Methods
    func activate() {
        do {
            try audioSession.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }
    
    func setStreamResolver(_ resolver: StreamResolver) {
        self.streamResolver = resolver
    }
    
    func play(_ track: Track, queue: [Track] = [], startIndex: Int = 0) {
        self.queue = queue.isEmpty ? [track] : queue
        self.currentIndex = startIndex
        loadAndPlay(track)
    }
    
    func playPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        position = 0
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime) { [weak self] _ in
            self?.position = time
        }
    }
    
    func seekForward(_ seconds: TimeInterval = 15) {
        seek(to: min(position + seconds, duration))
    }
    
    func seekBackward(_ seconds: TimeInterval = 15) {
        seek(to: max(position - seconds, 0))
    }
    
    func next() {
        guard !queue.isEmpty else { return }
        
        if shuffleMode == .on {
            currentIndex = Int.random(in: 0..<queue.count)
        } else {
            currentIndex = (currentIndex + 1) % queue.count
        }
        
        if currentIndex < queue.count {
            loadAndPlay(queue[currentIndex])
        }
    }
    
    func previous() {
        guard !queue.isEmpty else { return }
        
        if position > 3 {
            seek(to: 0)
            return
        }
        
        if shuffleMode == .on {
            currentIndex = Int.random(in: 0..<queue.count)
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        
        if currentIndex < queue.count {
            loadAndPlay(queue[currentIndex])
        }
    }
    
    func setQueue(_ newQueue: [Track], startIndex: Int = 0) {
        queue = newQueue
        currentIndex = startIndex
        if startIndex < queue.count {
            loadAndPlay(queue[startIndex])
        }
        saveQueueToDatabase()
    }
    
    func addToQueue(_ track: Track, at index: Int? = nil) {
        if let index = index {
            queue.insert(track, at: index)
            if index <= currentIndex {
                currentIndex += 1
            }
        } else {
            queue.append(track)
        }
        saveQueueToDatabase()
    }
    
    func removeFromQueue(at index: Int) {
        guard index < queue.count else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex && currentIndex >= queue.count {
            currentIndex = queue.count - 1
        }
        saveQueueToDatabase()
    }
    
    func clearQueue() {
        queue.removeAll()
        currentIndex = -1
        stop()
        saveQueueToDatabase()
    }
    
    func setVolume(_ volume: Float) {
        self.volume = volume
    }
    
    func setSpeed(_ speed: Float) {
        self.playbackSpeed = speed
    }
    
    func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "player.repeatMode")
    }
    
    func setShuffleMode(_ mode: ShuffleMode) {
        self.shuffleMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "player.shuffleMode")
    }
    
    func setAudioQuality(_ quality: AudioQuality) {
        self.audioQuality = quality
        if let track = currentTrack {
            loadAndPlay(track)
        }
    }
    
    func setCrossfadeDuration(_ duration: TimeInterval) {
        self.crossfadeDuration = duration
        UserDefaults.standard.set(duration, forKey: "player.crossfadeDuration")
    }
    
    // Sleep Timer
    func setSleepTimer(_ duration: TimeInterval?) {
        sleepTimer?.invalidate()
        sleepTimerRemaining = duration
        
        if let duration = duration, duration > 0 {
            sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.sleepTimerRemaining ?? 0 <= 1 {
                        self.pause()
                        self.sleepTimerRemaining = nil
                        timer.invalidate()
                    } else {
                        self.sleepTimerRemaining! -= 1
                    }
                }
            }
        }
    }
    
    var sleepTimerLabel: String {
        guard let remaining = sleepTimerRemaining else { return "Off" }
        if remaining == -1 { return "End of Track" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Equalizer
    private func updateEqualizer() {
        guard let eqNode = equalizerNode else { return }
        
        if equalizerPreset == .custom {
            updateEqualizerBands()
        } else {
            let bands = equalizerPreset.bands
            for (index, gain) in bands.enumerated() {
                let band = eqNode.bands[index]
                band.gain = gain
                band.bypass = !isEqualizerEnabled
            }
        }
    }
    
    private func updateEqualizerBands() {
        guard let eqNode = equalizerNode else { return }
        
        for (index, gain) in equalizerBands.enumerated() {
            let band = eqNode.bands[index]
            band.gain = gain
            band.bypass = !isEqualizerEnabled
        }
    }
    
    // MARK: - Library Scanning
    func scanLocalLibrary() async -> [Track] {
        let fileManager = FileManager.default
        let musicURLs = fileManager.urls(for: .musicDirectory, in: .userDomainMask)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        var tracks: [Track] = []
        let supportedExtensions = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "opus", "alac"]
        
        for url in musicURLs + [documentsURL] {
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey]) {
                for case let fileURL as URL in enumerator {
                    guard fileURL.isFileURL,
                          supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                    
                    if let track = await extractMetadata(from: fileURL) {
                        tracks.append(track)
                    }
                }
            }
        }
        
        // Save to database
        do {
            try database.saveTracks(tracks)
        } catch {
            print("Failed to save local tracks: \(error)")
        }
        
        return tracks
    }
    
    private func extractMetadata(from url: URL) async -> Track? {
        let asset = AVURLAsset(url: url)
        
        do {
            let metadata = try await asset.load(.commonMetadata)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            var title = url.deletingPathExtension().lastPathComponent
            var artist = "Unknown Artist"
            var album: String? = nil
            var artworkData: Data? = nil
            
            for item in metadata {
                guard let key = item.commonKey?.rawValue,
                      let value = try? await item.load(.value) else { continue }
                
                switch key {
                case "title": title = value as? String ?? title
                case "artist": artist = value as? String ?? artist
                case "albumName": album = value as? String
                case "artwork":
                    if let data = value as? Data {
                        artworkData = data
                    }
                default: break
                }
            }
            
            let track = Track(
                id: UUID().uuidString,
                videoId: "local_\(url.path.hashValue)",
                title: title,
                artistName: artist,
                artistId: nil,
                albumName: album,
                albumId: nil,
                duration: durationSeconds,
                artworkURL: nil, // Would save artwork data separately
                isExplicit: false,
                audioQuality: .lossless,
                lyrics: nil,
                source: .local
            )
            
            // Save artwork if available
            if let artworkData = artworkData {
                saveArtwork(artworkData, for: track.id)
            }
            
            return track
        } catch {
            print("Failed to extract metadata from \(url): \(error)")
            return nil
        }
    }
    
    private func saveArtwork(_ data: Data, for trackId: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let artworkDir = documentsPath.appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: artworkDir, withIntermediateDirectories: true)
        let artworkURL = artworkDir.appendingPathComponent("\(trackId).jpg")
        try? data.write(to: artworkURL)
    }
    
    // MARK: - Private Methods
    private func setupAudioEngine() {
        mixerNode = audioEngine.mainMixerNode
        
        equalizerNode = AVAudioUnitEQ(numberOfBands: 10)
        if let eq = equalizerNode {
            for (index, freq) in [32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0].enumerated() {
                let band = eq.bands[index]
                band.filterType = .parametric
                band.frequency = freq
                band.bandwidth = 1.0
                band.gain = 0
                band.bypass = true
            }
            audioEngine.attach(eq)
        }
        
        spatialAudioNode = AVAudioEnvironmentNode()
        if let spatial = spatialAudioNode {
            audioEngine.attach(spatial)
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnWifi = path.usesInterfaceType(.wifi)
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "network.monitor"))
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.handlePlaybackEnded()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .sink { [weak self] notification in
                self?.handlePlaybackError(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func loadAndPlay(_ track: Track) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let streamURL = try await resolveStreamURL(for: track, quality: getCurrentQuality())
                await MainActor.run {
                    self.playStream(url: streamURL, track: track)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func playStream(url: URL, track: Track) {
        cleanupPlayer()
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        self.playerItem = item
        
        let player = AVPlayer(playerItem: item)
        player.volume = volume
        player.rate = playbackSpeed
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updatePosition(time)
        }
        
        item.publisher(for: \.isPlaybackBufferEmpty)
            .sink { [weak self] isBuffering in
                self?.isBuffering = isBuffering
            }
            .store(in: &cancellables)
        
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] likelyToKeepUp in
                self?.isLoading = !likelyToKeepUp
            }
            .store(in: &cancellables)
        
        item.publisher(for: \.duration)
            .compactMap { $0 }
            .sink { [weak self] duration in
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite && seconds > 0 {
                    self?.duration = seconds
                }
            }
            .store(in: &cancellables)
        
        if isGaplessEnabled || isCrossfadeEnabled {
            preloadNextTrack()
        }
        
        player.play()
        isPlaying = true
        isLoading = false
        currentTrack = track
        
        updateNowPlayingInfo()
        
        // Add to history
        if !history.contains(where: { $0.id == track.id }) {
            history.insert(track, at: 0)
            if history.count > 100 {
                history.removeLast()
            }
        }
        
        // Persist to database
        Task {
            try? database.addToHistory(HistoryEntry(trackId: track.id, playedAt: Date(), position: 0, completed: false))
            try? database.incrementPlayCount(track.id)
        }
    }
    
    private func preloadNextTrack() {
        guard currentIndex + 1 < queue.count else { return }
        let nextTrack = queue[currentIndex + 1]
        
        Task {
            do {
                let streamURL = try await resolveStreamURL(for: nextTrack, quality: getCurrentQuality())
                await MainActor.run {
                    let asset = AVURLAsset(url: streamURL)
                    let item = AVPlayerItem(asset: asset)
                    self.nextPlayerItem = item
                    self.nextPlayer = AVPlayer(playerItem: item)
                    self.nextPlayer?.volume = 0
                }
            } catch {
                print("Failed to preload next track: \(error)")
            }
        }
    }
    
    private func handlePlaybackEnded() {
        if isCrossfadeEnabled && nextPlayer != nil {
            startCrossfade()
        } else {
            next()
        }
    }
    
    private func startCrossfade() {
        guard let currentPlayer = player,
              let nextPlayer = nextPlayer,
              let nextItem = nextPlayerItem else {
            next()
            return
        }
        
        let fadeOutDuration = crossfadeDuration
        let fadeInDuration = crossfadeDuration
        
        currentPlayer.volume = 1.0
        let fadeOutStep = 1.0 / fadeOutDuration
        crossfadeTimer?.invalidate()
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            let newVolume = max(0, currentPlayer.volume - Float(fadeOutStep * 0.1))
            currentPlayer.volume = newVolume
            
            let nextVolume = min(1.0, nextPlayer.volume + Float(fadeInStep * 0.1))
            nextPlayer.volume = nextVolume
            
            if newVolume <= 0 {
                timer.invalidate()
                self.finishCrossfade()
            }
        }
    }
    
    private func finishCrossfade() {
        player?.pause()
        player = nextPlayer
        playerItem = nextPlayerItem
        player?.volume = volume
        player?.rate = playbackSpeed
        
        nextPlayer = nil
        nextPlayerItem = nil
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updatePosition(time)
        }
        
        currentIndex += 1
        if currentIndex < queue.count {
            currentTrack = queue[currentIndex]
        }
        
        updateNowPlayingInfo()
        preloadNextTrack()
    }
    
    private func handlePlaybackError(_ notification: Notification) {
        isLoading = false
        error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "Playback failed"
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        switch reason {
        case .oldDeviceUnavailable:
            pause()
        default:
            break
        }
    }
    
    private func updatePosition(_ time: CMTime) {
        position = CMTimeGetSeconds(time)
    }
    
    private func cleanupPlayer() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player?.pause()
        player = nil
        playerItem = nil
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
    }
    
    private func getCurrentQuality() -> AudioQuality {
        isOnWifi ? wifiQuality : mobileQuality
    }
    
    private func resolveStreamURL(for track: Track, quality: AudioQuality) async throws -> URL {
        if let resolver = streamResolver {
            return try await resolver.resolve(trackId: track.id, quality: quality)
        }
        
        // Fallback for local files
        if track.source == .local {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let artworkDir = documentsPath.appendingPathComponent("Artwork", isDirectory: true)
            let localURL = artworkDir.appendingPathComponent("\(track.id).m4a")
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
        }
        
        throw NSError(domain: "PlayerController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Stream URL resolution not implemented"])
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0,
        ]
        
        if let albumName = track.albumName {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumName
        }
        
        if let artworkURL = track.artworkURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func restoreState() {
        volume = UserDefaults.standard.float(forKey: "player.volume")
        if volume == 0 { volume = 1.0 }
        
        crossfadeDuration = UserDefaults.standard.double(forKey: "player.crossfadeDuration")
        if crossfadeDuration == 0 { crossfadeDuration = 8.0 }
        
        isCrossfadeEnabled = UserDefaults.standard.bool(forKey: "player.isCrossfadeEnabled")
        isGaplessEnabled = UserDefaults.standard.bool(forKey: "player.isGaplessEnabled")
        isAutomixEnabled = UserDefaults.standard.bool(forKey: "player.isAutomixEnabled")
        
        if let repeatModeRaw = UserDefaults.standard.string(forKey: "player.repeatMode"),
           let mode = RepeatMode(rawValue: repeatModeRaw) {
            repeatMode = mode
        }
        
        if let shuffleModeRaw = UserDefaults.standard.string(forKey: "player.shuffleMode"),
           let mode = ShuffleMode(rawValue: shuffleModeRaw) {
            shuffleMode = mode
        }
        
        if let eqPresetRaw = UserDefaults.standard.string(forKey: "player.eqPreset"),
           let preset = EqualizerPreset(rawValue: eqPresetRaw) {
            equalizerPreset = preset
        }
    }
    
    func saveState() {
        UserDefaults.standard.set(volume, forKey: "player.volume")
        UserDefaults.standard.set(crossfadeDuration, forKey: "player.crossfadeDuration")
        UserDefaults.standard.set(isCrossfadeEnabled, forKey: "player.isCrossfadeEnabled")
        UserDefaults.standard.set(isGaplessEnabled, forKey: "player.isGaplessEnabled")
        UserDefaults.standard.set(isAutomixEnabled, forKey: "player.isAutomixEnabled")
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "player.repeatMode")
        UserDefaults.standard.set(shuffleMode.rawValue, forKey: "player.shuffleMode")
        UserDefaults.standard.set(equalizerPreset.rawValue, forKey: "player.eqPreset")
    }
    
    private func loadQueueFromDatabase() {
        // Load last queue from database if needed
    }
    
    private func saveQueueToDatabase() {
        // Save queue to database for persistence
    }
}

// MARK: - Stream Resolver Protocol (to be implemented by shared module)
protocol StreamResolver {
    func resolve(trackId: String, quality: AudioQuality) async throws -> URL
}

enum RepeatMode: String, CaseIterable, Codable {
    case off = "off"
    case all = "all"
    case one = "one"
}

enum ShuffleMode: String, CaseIterable, Codable {
    case off = "off"
    case on = "on"
    case smart = "smart"
}

// Need to import Network framework
import Network