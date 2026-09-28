import Foundation
import Combine
import AVFoundation

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var activeDownloads: [DownloadTask] = []
    @Published var completedDownloads: [DownloadTask] = []
    @Published var downloadProgress: [String: Double] = [:]
    
    private let fileManager = FileManager.default
    private let downloadsDirectory: URL
    private let metadataQueue = DispatchQueue(label: "com.bitchord.metadata", qos: .utility)
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressObservations: [String: NSKeyValueObservation] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadsDirectory = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        loadCompletedDownloads()
    }
    
    // MARK: - Public Methods
    func queueDownload(track: Track, quality: AudioQuality) -> DownloadTask {
        let task = DownloadTask(
            id: UUID().uuidString,
            trackId: track.id,
            trackTitle: track.title,
            artistName: track.artistName,
            albumName: track.albumName,
            artworkURL: track.artworkURL,
            quality: quality,
            status: .queued,
            progress: 0,
            totalBytes: 0,
            downloadedBytes: 0,
            localURL: nil,
            error: nil,
            createdAt: Date()
        )
        
        activeDownloads.append(task)
        startDownload(task)
        return task
    }
    
    func pauseDownload(_ taskId: String) {
        guard let task = downloadTasks[taskId] else { return }
        task.cancel(byProducingResumeData: { [weak self] resumeData in
            Task { @MainActor in
                if let data = resumeData {
                    self?.updateTask(taskId) { $0.resumeData = data }
                }
                self?.updateTask(taskId) { $0.status = .paused }
            }
        })
    }
    
    func resumeDownload(_ taskId: String) {
        guard var task = activeDownloads.first(where: { $0.id == taskId }),
              task.status == .paused else { return }
        
        if let resumeData = task.resumeData {
            let downloadTask = URLSession.shared.downloadTask(withResumeData: resumeData)
            downloadTasks[taskId] = downloadTask
            setupProgressObservation(taskId: taskId, task: downloadTask)
            downloadTask.resume()
        } else {
            startDownload(task)
        }
    }
    
    func cancelDownload(_ taskId: String) {
        downloadTasks[taskId]?.cancel()
        downloadTasks.removeValue(forKey: taskId)
        progressObservations[taskId]?.invalidate()
        progressObservations.removeValue(forKey: taskId)
        removeActiveDownload(taskId)
    }
    
    func retryDownload(_ taskId: String) {
        guard var task = activeDownloads.first(where: { $0.id == taskId }) else { return }
        task.status = .queued
        task.error = nil
        task.progress = 0
        task.downloadedBytes = 0
        updateActiveDownload(task)
        startDownload(task)
    }
    
    func removeDownload(_ taskId: String) {
        if let index = completedDownloads.firstIndex(where: { $0.id == taskId }) {
            let task = completedDownloads[index]
            if let localURL = task.localURL {
                try? fileManager.removeItem(at: localURL)
            }
            completedDownloads.remove(at: index)
            saveCompletedDownloads()
        }
    }
    
    func clearCompleted() {
        completedDownloads.removeAll()
        saveCompletedDownloads()
    }
    
    func getLocalPath(for trackId: String) -> URL? {
        completedDownloads.first { $0.trackId == trackId }?.localURL
    }
    
    func getStorageUsage() -> StorageUsage {
        let totalBytes = (try? fileManager.attributesOfFileSystem(forPath: downloadsDirectory.path)[.systemSize] as? Int64) ?? 0
        let usedBytes = completedDownloads.reduce(0) { $0 + $1.totalBytes }
        let downloadCount = completedDownloads.count
        
        return StorageUsage(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            availableBytes: totalBytes - usedBytes,
            downloadCount: downloadCount
        )
    }
    
    // MARK: - Private Methods
    private func startDownload(_ task: DownloadTask) {
        guard let streamURL = resolveStreamURL(for: task.trackId, quality: task.quality) else {
            updateTask(task.id) { $0.status = .failed; $0.error = "Could not resolve stream URL" }
            return
        }
        
        updateTask(task.id) { $0.status = .downloading }
        
        var request = URLRequest(url: streamURL)
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        
        let downloadTask = URLSession.shared.downloadTask(with: request) { [weak self] localURL, response, error in
            Task { @MainActor in
                self?.handleDownloadCompletion(taskId: task.id, localURL: localURL, response: response, error: error)
            }
        }
        
        setupProgressObservation(taskId: task.id, task: downloadTask)
        downloadTasks[task.id] = downloadTask
        downloadTask.resume()
    }
    
    private func setupProgressObservation(taskId: String, task: URLSessionDownloadTask) {
        let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            Task { @MainActor in
                self?.updateProgress(taskId: taskId, progress: progress.fractionCompleted)
                self?.updateBytes(taskId: taskId, progress: progress)
            }
        }
        progressObservations[taskId] = observation
    }
    
    private func handleDownloadCompletion(taskId: String, localURL: URL?, response: URLResponse?, error: Error?) {
        downloadTasks.removeValue(forKey: taskId)
        progressObservations[taskId]?.invalidate()
        progressObservations.removeValue(forKey: taskId)
        
        if let error = error {
            updateTask(taskId) { $0.status = .failed; $0.error = error.localizedDescription }
            return
        }
        
        guard let localURL = localURL else {
            updateTask(taskId) { $0.status = .failed; $0.error = "No file downloaded" }
            return
        }
        
        // Move to permanent location
        let destinationURL = downloadsDirectory.appendingPathComponent("\(taskId).m4a")
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: localURL, to: destinationURL)
            
            let fileSize = (try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
            
            updateTask(taskId) {
                $0.status = .completed
                $0.progress = 1.0
                $0.downloadedBytes = fileSize
                $0.totalBytes = fileSize
                $0.localURL = destinationURL
            }
            
            // Move to completed
            if let index = activeDownloads.firstIndex(where: { $0.id == taskId }) {
                let completedTask = activeDownloads.remove(at: index)
                completedDownloads.insert(completedTask, at: 0)
                saveCompletedDownloads()
            }
            
            // Tag the file with metadata
            if let task = completedDownloads.first(where: { $0.id == taskId }) {
                metadataQueue.async { [weak self] in
                    self?.tagDownloadedFile(task: task, url: destinationURL)
                }
            }
            
        } catch {
            updateTask(taskId) { $0.status = .failed; $0.error = error.localizedDescription }
        }
    }
    
    private func tagDownloadedFile(task: DownloadTask, url: URL) {
        let asset = AVURLAsset(url: url)
        
        // Create metadata
        var metadataItems: [AVMetadataItem] = []
        
        // Title
        if let titleItem = createMetadataItem(
            key: .commonKeyTitle,
            value: task.trackTitle
        ) {
            metadataItems.append(titleItem)
        }
        
        // Artist
        if let artistItem = createMetadataItem(
            key: .commonKeyArtist,
            value: task.artistName
        ) {
            metadataItems.append(artistItem)
        }
        
        // Album
        if let albumName = task.albumName,
           let albumItem = createMetadataItem(
            key: .commonKeyAlbumName,
            value: albumName
        ) {
            metadataItems.append(albumItem)
        }
        
        // Artwork
        if let artworkURL = task.artworkURL,
           let artworkData = try? Data(contentsOf: artworkURL),
           let artworkItem = createMetadataItem(
            key: .commonKeyArtwork,
            value: artworkData
        ) {
            metadataItems.append(artworkItem)
        }
        
        // Write metadata
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        exportSession?.outputURL = url
        exportSession?.outputFileType = .m4a
        exportSession?.metadata = metadataItems
        
        exportSession?.exportAsynchronously {
            if exportSession?.status == .failed {
                print("Metadata tagging failed: \(exportSession?.error?.localizedDescription ?? "Unknown")")
            }
        }
    }
    
    private func createMetadataItem(key: AVMetadataKey, value: Any) -> AVMetadataItem? {
        let item = AVMutableMetadataItem()
        item.key = key as (NSCopying & NSObjectProtocol)?
        item.keySpace = .common
        item.value = value as (NSCopying & NSObjectProtocol)?
        item.locale = Locale.current
        return item
    }
    
    private func updateProgress(taskId: String, progress: Double) {
        downloadProgress[taskId] = progress
        updateTask(taskId) { $0.progress = progress }
    }
    
    private func updateBytes(taskId: String, progress: Progress) {
        updateTask(taskId) {
            $0.downloadedBytes = progress.completedUnitCount
            $0.totalBytes = progress.totalUnitCount > 0 ? progress.totalUnitCount : $0.totalBytes
        }
    }
    
    private func updateTask(_ taskId: String, transform: (inout DownloadTask) -> Void) {
        if let index = activeDownloads.firstIndex(where: { $0.id == taskId }) {
            var task = activeDownloads[index]
            transform(&task)
            activeDownloads[index] = task
        }
    }
    
    private func updateActiveDownload(_ task: DownloadTask) {
        if let index = activeDownloads.firstIndex(where: { $0.id == task.id }) {
            activeDownloads[index] = task
        }
    }
    
    private func removeActiveDownload(_ taskId: String) {
        activeDownloads.removeAll { $0.id == taskId }
        downloadProgress.removeValue(forKey: taskId)
    }
    
    private func resolveStreamURL(for trackId: String, quality: AudioQuality) -> URL? {
        // This would call the shared module's stream extractor
        // For now, return nil - needs integration with KMP shared module
        return nil
    }
    
    private func loadCompletedDownloads() {
        let manifestURL = downloadsDirectory.appendingPathComponent("manifest.json")
        if let data = try? Data(contentsOf: manifestURL),
           let downloads = try? JSONDecoder().decode([DownloadTask].self, from: data) {
            completedDownloads = downloads.filter { fileManager.fileExists(atPath: $0.localURL?.path ?? "") }
        }
    }
    
    private func saveCompletedDownloads() {
        let manifestURL = downloadsDirectory.appendingPathComponent("manifest.json")
        if let data = try? JSONEncoder().encode(completedDownloads) {
            try? data.write(to: manifestURL)
        }
    }
}

// MARK: - Models
struct DownloadTask: Identifiable, Codable, Equatable {
    let id: String
    let trackId: String
    let trackTitle: String
    let artistName: String
    let albumName: String?
    let artworkURL: URL?
    let quality: AudioQuality
    var status: DownloadStatus
    var progress: Double
    var totalBytes: Int64
    var downloadedBytes: Int64
    var localURL: URL?
    var error: String?
    let createdAt: Date
    var completedAt: Date?
    var resumeData: Data?
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var speed: String {
        "0 KB/s"
    }
}

enum DownloadStatus: String, Codable, CaseIterable {
    case queued = "queued"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var systemImage: String {
        switch self {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .queued: return .gray
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

struct StorageUsage: Codable, Equatable {
    let totalBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64
    let downloadCount: Int
    
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
    }
}