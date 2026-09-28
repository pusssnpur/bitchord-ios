import SwiftUI
import Combine

struct NowPlayingView: View {
    @EnvironmentObject var playerController: PlayerController
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var dragOffset: CGSize = .zero
    @State private var showingLyrics = false
    @State private var showingQueue = false
    @State private var artworkScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var isArtworkAnimating = false
    
    private let dismissThreshold: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with album colors
                backgroundView
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Drag indicator
                    dragIndicator
                    
                    // Artwork with animations
                    artworkSection
                        .frame(height: geometry.size.height * 0.55)
                    
                    // Track info
                    trackInfoSection
                        .padding(.horizontal, 24)
                    
                    // Progress bar
                    progressSection
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    // Playback controls
                    controlsSection
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                    
                    // Secondary controls
                    secondaryControlsSection
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    Spacer()
                }
                .offset(y: max(0, dragOffset.height))
                .scaleEffect(dragOffset.height > 0 ? 1 - dragOffset.height / 1000 : 1)
                .opacity(dragOffset.height > 0 ? 1 - dragOffset.height / 500 : 1)
                
                // Lyrics overlay
                if showingLyrics {
                    LyricsView()
                        .environmentObject(playerController)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
                
                // Queue overlay
                if showingQueue {
                    QueueView()
                        .environmentObject(playerController)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(1)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > dismissThreshold || value.predictedEndTranslation.height > dismissThreshold {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingLyrics)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingQueue)
        .onAppear {
            startArtworkAnimation()
        }
        .onDisappear {
            stopArtworkAnimation()
        }
        .onChange(of: playerController.currentTrack) { _, newTrack in
            if newTrack != nil {
                startArtworkAnimation()
                if let artworkURL = newTrack?.artworkURL {
                    loadArtworkColors(from: artworkURL)
                }
            }
        }
    }
    
    // MARK: - Background
    @ViewBuilder
    private var backgroundView: some View {
        if let colors = themeManager.currentAlbumColors {
            colors.background
                .ignoresSafeArea()
            
            // Blurred artwork behind
            if let track = playerController.currentTrack,
               let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 80)
                        .opacity(0.3)
                } placeholder: {
                    Color.clear
                }
                .ignoresSafeArea()
            }
        } else {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
        
        // Frosted glass overlay
        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
            .ignoresSafeArea()
    }
    
    // MARK: - Drag Indicator
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
    
    // MARK: - Artwork Section
    private var artworkSection: some View {
        ZStack {
            // Rotating vinyl effect for playing
            if playerController.isPlaying && !showingLyrics {
                VinylRecordView(rotationAngle: $rotationAngle)
                    .frame(width: 280, height: 280)
                    .opacity(0.15)
            }
            
            // Main artwork
            AsyncImage(url: playerController.currentTrack?.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .scaleEffect(artworkScale)
            .rotationEffect(.degrees(rotationAngle))
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    artworkScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        artworkScale = 1.0
                    }
                }
            }
            
            // Animated equalizer bars when playing
            if playerController.isPlaying {
                EqualizerBarsView()
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Track Info
    private var trackInfoSection: some View {
        VStack(spacing: 8) {
            if let track = playerController.currentTrack {
                Text(track.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(track.artistName)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let albumName = track.albumName {
                    Text(albumName)
                        .font(.subheadline)
                        .foregroundColor(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 4) {
            // Progress bar with scrubbing
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    // Buffered portion
                    if playerController.bufferedPosition > 0 {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(
                                width: geometry.size.width * CGFloat(playerController.bufferedPosition / max(playerController.duration, 1)),
                                height: 4
                            )
                    }
                    
                    // Played portion
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * CGFloat(playerController.position / max(playerController.duration, 1)),
                            height: 4
                        )
                    
                    // Scrubber handle
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 4)
                        .offset(x: geometry.size.width * CGFloat(playerController.position / max(playerController.duration, 1)) - 8)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    playerController.seek(to: playerController.duration * progress)
                                }
                        )
                }
            }
            .frame(height: 16)
            
            // Time labels
            HStack {
                Text(formatTime(playerController.position))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTime(playerController.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        HStack(spacing: 32) {
            // Shuffle
            Button(action: { playerController.shuffleMode = playerController.shuffleMode.next() }) {
                Image(systemName: shuffleIcon)
                    .font(.system(size: 20))
                    .foregroundColor(playerController.shuffleMode == .off ? .secondary : .accentColor)
            }
            
            // Previous
            Button(action: { playerController.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
            }
            
            // Play/Pause
            Button(action: { playerController.playPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 4)
                    
                    Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: playerController.isPlaying ? 0 : 2)
                }
            }
            .scaleEffect(playerController.isPlaying ? 1.0 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: playerController.isPlaying)
            
            // Next
            Button(action: { playerController.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
            }
            
            // Repeat
            Button(action: { playerController.repeatMode = playerController.repeatMode.next() }) {
                Image(systemName: repeatIcon)
                    .font(.system(size: 20))
                    .foregroundColor(playerController.repeatMode == .off ? .secondary : .accentColor)
            }
        }
    }
    
    // MARK: - Secondary Controls
    private var secondaryControlsSection: some View {
        HStack(spacing: 20) {
            // Lyrics
            Button(action: { withAnimation { showingLyrics.toggle() } }) {
                Image(systemName: showingLyrics ? "text.bubble.fill" : "text.bubble")
                    .font(.system(size: 22))
                    .foregroundColor(showingLyrics ? .accentColor : .secondary)
            }
            
            Spacer()
            
            // AirPlay
            AirPlayButton()
                .frame(width: 32, height: 32)
            
            Spacer()
            
            // Queue
            Button(action: { withAnimation { showingQueue.toggle() } }) {
                Image(systemName: showingQueue ? "list.bullet.fill" : "list.bullet")
                    .font(.system(size: 22))
                    .foregroundColor(showingQueue ? .accentColor : .secondary)
            }
        }
    }
    
    // MARK: - Helpers
    private var shuffleIcon: String {
        switch playerController.shuffleMode {
        case .off: return "shuffle"
        case .on: return "shuffle"
        case .smart: return "sparkles"
        }
    }
    
    private var repeatIcon: String {
        switch playerController.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startArtworkAnimation() {
        isArtworkAnimating = true
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    private func stopArtworkAnimation() {
        isArtworkAnimating = false
    }
    
    private func loadArtworkColors(from url: URL) {
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                themeManager.updateAlbumColors(from: image)
            }
        }
    }
}

// MARK: - Vinyl Record View
struct VinylRecordView: View {
    @Binding var rotationAngle: Double
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 4)
            
            // Grooves
            ForEach(0..<60) { i in
                Circle()
                    .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
                    .scaleEffect(0.2 + CGFloat(i) * 0.013)
            }
            
            // Center label
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
        }
        .rotationEffect(.degrees(rotationAngle))
    }
}

// MARK: - Equalizer Bars View
struct EqualizerBarsView: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0.1, count: 20)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.6))
                        .frame(
                            width: (geometry.size.width - 76) / 20,
                            height: geometry.size.height * barHeights[index]
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 0.1...0.3))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.02),
                            value: barHeights[index]
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 20)
            .onAppear {
                animateBars()
            }
        }
    }
    
    private func animateBars() {
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            for i in 0..<barHeights.count {
                barHeights[i] = CGFloat.random(in: 0.1...0.8)
            }
        }
    }
}

// MARK: - AirPlay Button
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let button = AVRoutePickerView()
        button.activeTintColor = UIColor.label
        button.tintColor = UIColor.secondaryLabel
        return button
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Lyrics View
struct LyricsView: View {
    @EnvironmentObject var playerController: PlayerController
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if let lyrics = playerController.currentTrack?.lyrics {
                            ForEach(lyrics.lines) { line in
                                LyricLineView(line: line, currentTime: playerController.position)
                                    .id(line.id)
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No lyrics available")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                Text("Lyrics will appear here when available")
                                    .font(.subheadline)
                                    .foregroundColor(.tertiary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
                }
                .onChange(of: playerController.position) { _, newPosition in
                    // Auto-scroll to current lyric line
                    if let lyrics = playerController.currentTrack?.lyrics,
                       let currentLine = lyrics.lines.first(where: { 
                           newPosition >= $0.startTime && newPosition < $0.endTime 
                       }) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(currentLine.id, anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("Lyrics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct LyricLineView: View {
    let line: LyricLine
    let currentTime: TimeInterval
    
    var isActive: Bool {
        currentTime >= line.startTime && currentTime < line.endTime
    }
    
    var progress: Double {
        guard line.endTime > line.startTime else { return 0 }
        return (currentTime - line.startTime) / (line.endTime - line.startTime)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            if let words = line.words, !words.isEmpty {
                // Word-by-word highlighting
                HStack(spacing: 4) {
                    ForEach(words) { word in
                        let wordProgress = min(1, max(0, (currentTime - word.startTime) / max(word.endTime - word.startTime, 0.001)))
                        Text(word.text + " ")
                            .font(.title2.weight(isActive ? .semibold : .regular))
                            .foregroundColor(isActive ? .primary : .secondary)
                            .overlay(
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(width: geo.size.width * wordProgress)
                                        .mask(Text(word.text + " ").font(.title2.weight(.semibold)))
                                }
                            )
                    }
                }
                .multilineTextAlignment(.center)
            } else {
                // Line-by-line highlighting
                Text(line.text)
                    .font(.title2.weight(isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .overlay(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * progress)
                                .mask(Text(line.text).font(.title2.weight(.semibold)))
                        }
                    )
            }
            
            if let translation = line.translation {
                Text(translation)
                    .font(.subheadline)
                    .foregroundColor(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Queue View
struct QueueView: View {
    @EnvironmentObject var playerController: PlayerController
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Now playing
                Section("Now Playing") {
                    if let track = playerController.currentTrack {
                        QueueTrackRow(track: track, isPlaying: true)
                    }
                }
                
                // Up next
                Section("Up Next") {
                    ForEach(Array(playerController.queue.enumerated()), id: \.element.id) { index, track in
                        if index > playerController.currentIndex {
                            QueueTrackRow(track: track, isPlaying: false)
                        }
                    }
                    .onMove { indices, newOffset in
                        // Handle reorder
                    }
                    .onDelete { indices in
                        // Handle delete
                    }
                }
                
                // History
                if !playerController.history.isEmpty {
                    Section("History") {
                        ForEach(playerController.history) { track in
                            QueueTrackRow(track: track, isPlaying: false)
                        }
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { playerController.clearQueue() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

struct QueueTrackRow: View {
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundColor(isPlaying ? .accentColor : .primary)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(track.formattedDuration)
                .font(.caption)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}