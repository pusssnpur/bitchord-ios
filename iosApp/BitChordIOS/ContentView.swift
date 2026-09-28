import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerController: PlayerController
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var showingNowPlaying = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                ExploreView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Explore")
                    }
                    .tag(1)
                
                LibraryView()
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Library")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .accentColor(.primary)
            
            // Mini player
            if playerController.currentTrack != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: playerController.currentTrack != nil)
        .fullScreenCover(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .environmentObject(playerController)
        }
        .onTapGesture {
            if showingNowPlaying {
                showingNowPlaying = false
            }
        }
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject var playerController: PlayerController
    @State private var showingFullPlayer = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: playerController.currentTrack?.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 56, height: 56)
            .cornerRadius(8)
            .shadow(radius: 4)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(playerController.currentTrack?.title ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(playerController.currentTrack?.artistName ?? "")
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 16) {
                Button(action: { playerController.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
                
                Button(action: { playerController.playPause() }) {
                    Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
                
                Button(action: { playerController.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
        )
        .onTapGesture {
            showingFullPlayer = true
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            NowPlayingView()
                .environmentObject(playerController)
        }
    }
}

// MARK: - Placeholder Views
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: .sectionHeaders) {
                    Section(header: SectionHeader(title: "Quick Picks")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(0..<5) { _ in
                                    AlbumCard()
                                        .frame(width: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Section(header: SectionHeader(title: "Recently Played")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(0..<5) { _ in
                                    TrackCard()
                                        .frame(width: 180)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Section(header: SectionHeader(title: "Made For You")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(0..<5) { _ in
                                    PlaylistCard()
                                        .frame(width: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ExploreView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Search bar
                    SearchBar(text: $searchText, placeholder: "Search songs, artists, albums...")
                        .padding(.horizontal)
                    
                    // Moods & Genres
                    SectionHeader(title: "Moods & Genres")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(["Pop", "Rock", "Hip Hop", "Electronic", "Jazz", "Classical", "R&B", "Country"], id: \.self) { genre in
                                GenreChip(title: genre)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Charts
                    SectionHeader(title: "Charts")
                    LazyVStack(spacing: 12) {
                        ForEach(0..<10) { index in
                            ChartRow(rank: index + 1, track: nil)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LibraryView: View {
    @State private var selectedSection = 0
    let sections = ["Playlists", "Albums", "Artists", "Songs", "Downloads"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library Section", selection: $selectedSection) {
                    ForEach(0..<sections.count, id: \.self) { index in
                        Text(sections[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedSection) {
                    PlaylistsLibraryView()
                        .tag(0)
                    AlbumsLibraryView()
                        .tag(1)
                    ArtistsLibraryView()
                        .tag(2)
                    SongsLibraryView()
                        .tag(3)
                    DownloadsLibraryView()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var playerController: PlayerController
    
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
                
                Section("Advanced") {
                    NavigationLink("Equalizer") {
                        EqualizerView()
                    }
                    
                    NavigationLink("Storage & Downloads") {
                        StorageView()
                    }
                    
                    NavigationLink("Last.fm Scrobbling") {
                        LastFMView()
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
        }
    }
}

// MARK: - UI Components
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.primary)
            Spacer()
            if let action = action {
                Button("See All", action: action)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
}

struct AlbumCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)
            
            Text("Album Title")
                .font(.subheadline.bold())
                .lineLimit(1)
            Text("Artist Name")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct TrackCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)
            
            Text("Track Title")
                .font(.subheadline.bold())
                .lineLimit(1)
            Text("Artist Name")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct PlaylistCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.8))
                )
            
            Text("Playlist Name")
                .font(.subheadline.bold())
                .lineLimit(1)
            Text("Curator • 50 songs")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct GenreChip: View {
    let title: String
    @State private var isPressed = false
    
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
            .foregroundColor(.accentColor)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct ChartRow: View {
    let rank: Int
    let track: Track?
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(rank <= 3 ? .accentColor : .secondary)
                .frame(width: 28)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track?.title ?? "Track Title")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(track?.artistName ?? "Artist Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
            }
        }
        .padding(.vertical, 4)
    }
}

// Library placeholder views
struct PlaylistsLibraryView: View { var body: some View { Text("Playlists").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct AlbumsLibraryView: View { var body: some View { Text("Albums").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct ArtistsLibraryView: View { var body: some View { Text("Artists").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct SongsLibraryView: View { var body: some View { Text("Songs").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct DownloadsLibraryView: View { var body: some View { Text("Downloads").frame(maxWidth: .infinity, maxHeight: .infinity) } }

// Settings subviews
struct SleepTimerPicker: View {
    @EnvironmentObject var playerController: PlayerController
    let options: [(String, TimeInterval?)] = [
        ("Off", nil),
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("45 min", 45 * 60),
        ("1 hour", 3600),
        ("End of Track", -1)
    ]
    
    var body: some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.0) {
                    playerController.setSleepTimer(option.1)
                }
            }
        } label: {
            HStack {
                Text("Sleep Timer")
                Spacer()
                Text(playerController.sleepTimerLabel)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct EqualizerView: View {
    @EnvironmentObject var playerController: PlayerController
    @State private var bands: [Float] = Array(repeating: 0, count: 10)
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Preset", selection: $playerController.equalizerPreset) {
                ForEach(EqualizerPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10, id: \.self) { index in
                    VStack {
                        Text("\(EqualizerPreset.frequencyLabels[index]) Hz")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * 0.6, height: geo.size.height * CGFloat((bands[index] + 12) / 24))
                                    .animation(.spring(), value: bands[index])
                            }
                        }
                        .frame(height: 150)
                        
                        Slider(value: $bands[index], in: -12...12, step: 1) {
                            Text("")
                        } minimumValueLabel: {
                            Text("-12").font(.caption2)
                        } maximumValueLabel: {
                            Text("+12").font(.caption2)
                        }
                        .rotationEffect(.degrees(-90))
                        .frame(width: 150)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Equalizer")
    }
}

struct StorageView: View { var body: some View { Text("Storage").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct LastFMView: View { var body: some View { Text("Last.fm").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct ListenTogetherView: View { var body: some View { Text("Listen Together").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct DiscordRPCView: View { var body: some View { Text("Discord RPC").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct WebDAVView: View { var body: some View { Text("WebDAV").frame(maxWidth: .infinity, maxHeight: .infinity) } }

// MARK: - Visual Effect Blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}