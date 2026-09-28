import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var playerController: PlayerController
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var showingLibraryScan = false
    @State private var showingImportPlaylist = false
    @State private var showingExportData = false
    @State private var showingClearCache = false
    @State private var cacheSize: String = "Calculating..."
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if authManager.isAuthenticated {
                        HStack {
                            AsyncImage(url: authManager.currentUser?.avatarURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(authManager.currentUser?.name ?? "User")
                                    .font(.headline)
                                Text(authManager.currentUser?.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    } else {
                        Button("Sign In with Google") {
                            authManager.signInWithGoogle()
                        }
                        Button("Sign In with YouTube Music") {
                            authManager.signInWithYouTubeMusic()
                        }
                        Button("Sign In with Discord") {
                            authManager.signInWithDiscord()
                        }
                        Button("Sign In with Last.fm") {
                            authManager.signInWithLastFm()
                        }
                        Button("Sign In with ListenBrainz") {
                            authManager.signInWithListenBrainz()
                        }
                    }
                }
                
                Section("Library") {
                    Button(action: { showingLibraryScan = true }) {
                        HStack {
                            Label("Scan Local Files", systemImage: "folder.badge.plus")
                            Spacer()
                            if showingLibraryScan {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(showingLibraryScan)
                    
                    Button(action: { showingImportPlaylist = true }) {
                        Label("Import Playlist", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingExportData = true }) {
                        Label("Export Library Data", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("Playback") {
                    Toggle("Gapless Playback", isOn: $playerController.isGaplessEnabled)
                    Toggle("Crossfade", isOn: $playerController.isCrossfadeEnabled)
                    
                    if playerController.isCrossfadeEnabled {
                        VStack(alignment: .leading) {
                            Text("Crossfade Duration: \(Int(playerController.crossfadeDuration))s")
                            Slider(value: $playerController.crossfadeDuration, in: 0...12, step: 1)
                        }
                    }
                    
                    Toggle("Automix (Beta)", isOn: $playerController.isAutomixEnabled)
                    Toggle("Skip Silence", isOn: $playerController.isSkipSilenceEnabled)
                    Toggle("Normalize Volume", isOn: $playerController.isVolumeNormalizationEnabled)
                    
                    NavigationLink("Equalizer") {
                        EqualizerView()
                    }
                }
                
                Section("Audio Quality") {
                    Picker("Wi-Fi Quality", selection: $playerController.wifiQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.rawValue.capitalized).tag(quality)
                        }
                    }
                    
                    Picker("Mobile Data Quality", selection: $playerController.mobileQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.rawValue.capitalized).tag(quality)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: $themeManager.colorSchemeOption) {
                        Text("System").tag(ColorSchemeOption.system)
                        Text("Light").tag(ColorSchemeOption.light)
                        Text("Dark").tag(ColorSchemeOption.dark)
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Dynamic Theming (Album Colors)", isOn: $themeManager.isDynamicThemingEnabled)
                }
                
                Section("Sleep Timer") {
                    SleepTimerPicker()
                }
                
                Section("Storage & Downloads") {
                    NavigationLink {
                        StorageDetailView()
                    } label: {
                        HStack {
                            Label("Storage", systemImage: "internaldrive")
                            Spacer()
                            Text(cacheSize)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink("Manage Downloads") {
                        DownloadsManagementView()
                    }
                    
                    Button(action: { showingClearCache = true }) {
                        Label("Clear Cache", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                Section("Integrations") {
                    NavigationLink("Last.fm Scrobbling") {
                        LastFMView()
                    }
                    
                    NavigationLink("ListenBrainz Scrobbling") {
                        ListenBrainzView()
                    }
                    
                    NavigationLink("Listen Together") {
                        ListenTogetherView()
                    }
                    
                    NavigationLink("Discord Rich Presence") {
                        DiscordRPCView()
                    }
                    
                    NavigationLink("WebDAV Sync") {
                        WebDAVView()
                    }
                }
                
                Section("Advanced") {
                    NavigationLink("Playback Statistics") {
                        StatsView()
                    }
                    
                    Button(action: { resetAllSettings() }) {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.6.0")
                            .foregroundColor(.secondary)
                    }
                    Link("GitHub Repository", destination: URL(string: "https://github.com/kushagrasinghx/BitChord")!)
                    Link("Report an Issue", destination: URL(string: "https://github.com/kushagrasinghx/BitChord/issues")!)
                    Text("Licensed under GPLv3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await calculateCacheSize()
            }
            .sheet(isPresented: $showingLibraryScan) {
                LibraryScanView()
            }
            .sheet(isPresented: $showingImportPlaylist) {
                ImportPlaylistView()
            }
            .sheet(isPresented: $showingExportData) {
                ExportDataView()
            }
            .alert("Clear Cache?", isPresented: $showingClearCache) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { clearCache() }
            } message: {
                Text("This will remove cached images and temporary files. Your downloads and library will not be affected.")
            }
        }
    }
    
    private func calculateCacheSize() async {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        do {
            let resourceValues = try cacheURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            let size = resourceValues.totalFileAllocatedSize ?? 0
            await MainActor.run {
                cacheSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        } catch {
            await MainActor.run {
                cacheSize = "Unknown"
            }
        }
    }
    
    private func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        cacheSize = "0 KB"
    }
    
    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        let keys = [
            "player.volume", "player.crossfadeDuration", "player.isCrossfadeEnabled",
            "player.isGaplessEnabled", "player.isAutomixEnabled", "player.repeatMode",
            "player.shuffleMode", "player.eqPreset", "theme.colorScheme", "theme.dynamicTheming"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        // Reset to defaults
        playerController.restoreState()
        themeManager.colorSchemeOption = .system
        themeManager.isDynamicThemingEnabled = true
    }
}

// MARK: - Subviews
struct StorageDetailView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var storageUsage: StorageUsage?
    
    var body: some View {
        List {
            if let usage = storageUsage {
                Section("Overview") {
                    HStack {
                        Text("Used")
                        Spacer()
                        Text(usage.formattedUsed)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Available")
                        Spacer()
                        Text(usage.formattedAvailable)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Downloads")
                        Spacer()
                        Text("\(usage.downloadCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: usage.usedPercentage)
                        .tint(.blue)
                }
                
                Section("Downloads") {
                    ForEach(downloadManager.completedDownloads) { download in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(download.trackTitle)
                                Text(download.artistName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(download.formattedSize)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            downloadManager.removeDownload(downloadManager.completedDownloads[index].id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Storage")
        .onAppear {
            storageUsage = downloadManager.getStorageUsage()
        }
    }
}

struct DownloadsManagementView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        List {
            Section("Active Downloads") {
                ForEach(downloadManager.activeDownloads) { task in
                    DownloadTaskRow(task: task)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        downloadManager.cancelDownload(downloadManager.activeDownloads[index].id)
                    }
                }
            }
            
            Section("Completed") {
                ForEach(downloadManager.completedDownloads) { task in
                    DownloadTaskRow(task: task)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        downloadManager.removeDownload(downloadManager.completedDownloads[index].id)
                    }
                }
            }
        }
        .navigationTitle("Downloads")
    }
}

struct DownloadTaskRow: View {
    let task: DownloadTask
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AsyncImage(url: task.artworkURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.trackTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(task.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Image(systemName: task.status.systemImage)
                        .foregroundColor(task.status.color)
                    
                    if task.status == .downloading {
                        ProgressView(value: task.progress)
                            .frame(width: 60)
                    }
                }
            }
            
            if task.status == .downloading {
                HStack {
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(task.speed)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            if task.status == .downloading {
                Button("Pause") { downloadManager.pauseDownload(task.id) }
                    .tint(.orange)
            } else if task.status == .paused {
                Button("Resume") { downloadManager.resumeDownload(task.id) }
                    .tint(.green)
            }
            
            if task.status == .failed {
                Button("Retry") { downloadManager.retryDownload(task.id) }
                    .tint(.blue)
            }
            
            Button("Cancel") { downloadManager.cancelDownload(task.id) }
                .tint(.red)
        }
    }
}

struct LibraryScanView: View {
    @EnvironmentObject var playerController: PlayerController
    @Environment(\.dismiss) var dismiss
    @State private var scannedTracks: [Track] = []
    @State private var isScanning = false
    @State private var progress: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                Text("Scan Local Music")
                    .font(.title.bold())
                
                Text("This will scan your Music folder and Documents for audio files and add them to your library.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isScanning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(progress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !scannedTracks.isEmpty {
                    VStack(spacing: 8) {
                        Text("Found \(scannedTracks.count) tracks")
                            .font(.headline)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button("Start Scan") {
                        startScan()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)
                }
            }
            .padding()
            .navigationTitle("Library Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isScanning {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }
    
    private func startScan() {
        isScanning = true
        progress = "Scanning..."
        
        Task {
            let tracks = await playerController.scanLocalLibrary()
            await MainActor.run {
                scannedTracks = tracks
                isScanning = false
                progress = "Found \(tracks.count) tracks"
            }
        }
    }
}

struct ImportPlaylistView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                Text("Import Playlist")
                    .font(.title.bold())
                
                Text("Import playlists from M3U, M3U8, or JSON files.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button("Select File") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Import Playlist")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.playlist, .json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        // Handle playlist import
    }
}

struct ExportDataView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                Text("Export Library Data")
                    .font(.title.bold())
                
                Text("Export your playlists, liked tracks, and history as JSON.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button("Generate Export") {
                    generateExport()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export Data")
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func generateExport() {
        // Generate export file
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct LastFMView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isAuthenticated = false
    @State private var status = "Not connected"
    
    var body: some View {
        Form {
            Section("Last.fm Account") {
                if isAuthenticated {
                    HStack {
                        Text("Connected as")
                        Spacer()
                        Text(username)
                            .foregroundColor(.secondary)
                    }
                    Button("Disconnect", role: .destructive) {
                        isAuthenticated = false
                        status = "Not connected"
                    }
                } else {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                    Button("Connect") {
                        // Authenticate
                        isAuthenticated = true
                        status = "Connected"
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(status)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Scrobbling Options") {
                Toggle("Scrobble Automatically", isOn: .constant(true))
                Toggle("Update Now Playing", isOn: .constant(true))
                Toggle("Only Scrobble on Wi-Fi", isOn: .constant(false))
            }
        }
        .navigationTitle("Last.fm")
    }
}

struct ListenBrainzView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isAuthenticated = false
    @State private var status = "Not connected"
    
    var body: some View {
        Form {
            Section("ListenBrainz Account") {
                if isAuthenticated {
                    HStack {
                        Text("Connected as")
                        Spacer()
                        Text(username)
                            .foregroundColor(.secondary)
                    }
                    Button("Disconnect", role: .destructive) {
                        isAuthenticated = false
                        status = "Not connected"
                    }
                } else {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                    Button("Connect") {
                        isAuthenticated = true
                        status = "Connected"
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(status)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Options") {
                Toggle("Submit Listens", isOn: .constant(true))
                Toggle("Submit Playing Now", isOn: .constant(true))
            }
        }
        .navigationTitle("ListenBrainz")
    }
}

struct ListenTogetherView: View {
    @State private var serverURL = "https://party.bitchord.app"
    @State private var partyCode = ""
    @State private var username = ""
    @State private var isHost = false
    @State private var isConnected = false
    
    var body: some View {
        Form {
            Section("Server") {
                TextField("Server URL", text: $serverURL)
                    .textInputAutocapitalization(.never)
            }
            
            Section("Join Party") {
                TextField("Party Code", text: $partyCode)
                    .textInputAutocapitalization(.never)
                TextField("Your Name", text: $username)
                Button(isConnected ? "Leave Party" : "Join Party") {
                    isConnected.toggle()
                }
                .disabled(username.isEmpty || (isConnected && partyCode.isEmpty))
            }
            
            Section("Create Party") {
                Toggle("Host Party", isOn: $isHost)
                if isHost {
                    Toggle("Public Party", isOn: .constant(true))
                    Stepper("Max Users: 50", value: .constant(50), in: 2...100)
                }
                Button("Create") {
                    // Create party
                }
                .disabled(username.isEmpty)
            }
        }
        .navigationTitle("Listen Together")
    }
}

struct DiscordRPCView: View {
    @State private var isEnabled = false
    @State private var isConnected = false
    @State private var clientId = ""
    
    var body: some View {
        Form {
            Section("Discord Rich Presence") {
                Toggle("Enable Discord RPC", isOn: $isEnabled)
                
                if isEnabled {
                    TextField("Application ID (Client ID)", text: $clientId)
                        .textInputAutocapitalization(.never)
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(isConnected ? .green : .secondary)
                    }
                    
                    if isConnected {
                        Button("Disconnect") {
                            isConnected = false
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Connect") {
                            isConnected = true
                        }
                        .disabled(clientId.isEmpty)
                    }
                }
            }
            
            Section("Display Options") {
                Toggle("Show Track Title", isOn: .constant(true))
                Toggle("Show Artist", isOn: .constant(true))
                Toggle("Show Album", isOn: .constant(true))
                Toggle("Show Progress", isOn: .constant(true))
                Toggle("Show Artwork", isOn: .constant(true))
                Toggle("Show Play/Pause Buttons", isOn: .constant(true))
            }
        }
        .navigationTitle("Discord RPC")
    }
}

struct WebDAVView: View {
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var remotePath = "/Music"
    @State private var isConnected = false
    @State private var autoSync = false
    
    var body: some View {
        Form {
            Section("WebDAV Server") {
                TextField("Server URL", text: $serverURL)
                    .textInputAutocapitalization(.never)
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                TextField("Remote Path", text: $remotePath)
                
                Button(isConnected ? "Disconnect" : "Connect") {
                    isConnected.toggle()
                }
                .disabled(serverURL.isEmpty || username.isEmpty)
            }
            
            Section("Sync Options") {
                Toggle("Auto Sync on Wi-Fi", isOn: $autoSync)
                Toggle("Sync Downloads", isOn: .constant(true))
                Toggle("Sync Playlists", isOn: .constant(true))
                Toggle("Sync Liked Tracks", isOn: .constant(true))
                
                Button("Sync Now") {
                    // Trigger sync
                }
                .disabled(!isConnected)
            }
            
            Section("Status") {
                HStack {
                    Text("Connection")
                    Spacer()
                    Text(isConnected ? "Connected" : "Disconnected")
                        .foregroundColor(isConnected ? .green : .secondary)
                }
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text("Never")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("WebDAV Sync")
    }
}

struct StatsView: View {
    var body: some View {
        List {
            Section("Playback") {
                StatRow(label: "Total Plays", value: "1,234")
                StatRow(label: "Total Time", value: "45h 32m")
                StatRow(label: "Unique Tracks", value: "567")
                StatRow(label: "Unique Artists", value: "89")
            }
            
            Section("Library") {
                StatRow(label: "Tracks", value: "2,341")
                StatRow(label: "Albums", value: "312")
                StatRow(label: "Artists", value: "445")
                StatRow(label: "Playlists", value: "23")
            }
            
            Section("Downloads") {
                StatRow(label: "Downloaded Tracks", value: "156")
                StatRow(label: "Storage Used", value: "2.3 GB")
            }
        }
        .navigationTitle("Statistics")
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}