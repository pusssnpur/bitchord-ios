# BitChord iOS

A Kotlin Multiplatform (KMP) port of the BitChord Android app - an aesthetic YouTube Music client for iOS.

## Architecture

```
BitChordIOS/
├── shared/                 # KMP shared module (Kotlin)
│   ├── src/
│   │   ├── commonMain/     # Shared business logic
│   │   │   ├── data/       # Repository interfaces, models
│   │   │   ├── playback/   # Player controller, queue manager
│   │   │   ├── auth/       # Authentication interfaces
│   │   │   ├── download/   # Download manager interfaces
│   │   │   └── ui/         # Shared Compose UI components
│   │   ├── androidMain/    # Android-specific implementations
│   │   └── iosMain/        # iOS-specific implementations
│   └── build.gradle.kts
├── iosApp/                 # iOS App (Swift/SwiftUI)
│   └── BitChordIOS/        # Xcode project
│       ├── BitChordIOSApp.swift
│       ├── ContentView.swift
│       ├── PlayerController.swift
│       ├── AuthManager.swift
│       ├── DownloadManager.swift
│       ├── ThemeManager.swift
│       ├── KeychainManager.swift
│       ├── NowPlayingView.swift
│       └── Info.plist
├── settings.gradle.kts
├── build.gradle.kts
└── Podfile
```

## Key Components

### Shared Module (Kotlin)
- **Models**: `Track`, `Album`, `Artist`, `Playlist`, `Lyrics`, `SearchResults`
- **Repositories**: `MediaRepository`, `AuthRepository`, `DownloadRepository`
- **Playback**: `PlayerController`, `QueueManager`, `TrackAnalysis` (smart features)
- **UI**: Shared Compose components for potential Compose Multiplatform use

### iOS App (Swift/SwiftUI)
- **PlayerController**: AVFoundation-based player with gapless playback, crossfade, Automix
- **AuthManager**: OAuth2 for Google, YouTube Music, Discord, Last.fm, ListenBrainz
- **DownloadManager**: Background downloads with metadata tagging
- **ThemeManager**: Dynamic album-color theming with Material 3
- **NowPlayingView**: Full-screen player with animated artwork, lyrics, queue

## Features Implemented

### Playback
- [x] AVFoundation-based player
- [x] Gapless playback
- [x] Crossfade (0-12s)
- [x] Playback speed (0.5x-2.0x)
- [x] Sleep timer
- [x] Background audio
- [x] Remote control support (lock screen, Control Center)
- [x] AirPlay support
- [x] Equalizer (10-band, presets)
- [x] Spatial audio support

### Smart Features (Stubbed)
- [ ] Beat tracking & tempo analysis
- [ ] Vocal detection
- [ ] Harmonic mixing
- [ ] Automix transitions

### UI/UX
- [x] Material 3 theming
- [x] Dynamic album colors
- [x] Frosted glass (VisualEffectBlur)
- [x] Animated artwork (rotation, equalizer bars)
- [x] Word-synced lyrics
- [x] Mini player
- [x] Full-screen Now Playing
- [x] Queue management
- [x] Tab navigation (Home, Explore, Library, Settings)

### Connectivity
- [ ] YouTube Music API (Innertube)
- [ ] NewPipeExtractor port
- [ ] Discord Rich Presence
- [ ] Last.fm / ListenBrainz scrobbling
- [ ] Listen Together party sync
- [ ] WebDAV sync

### Offline
- [x] Download manager
- [ ] Metadata tagging (ID3, artwork, lyrics)
- [ ] Storage management

## Building

### Prerequisites
- Xcode 15+
- iOS 17.0+ deployment target
- JDK 17+
- Android Studio (for KMP development)
- CocoaPods (`sudo gem install cocoapods`)

### Setup
```bash
# 1. Install CocoaPods dependencies
cd iosApp
pod install

# 2. Open Xcode workspace
open BitChordIOS.xcworkspace

# 3. Build and run from Xcode
```

### KMP Development
```bash
# Build shared framework
./gradlew :shared:embedAndSignAppleFrameworkForXcode

# Or use the Gradle task in Android Studio
```

## Project Structure Details

### Shared Module Dependencies
```kotlin
// Core
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.6.1")

// Networking
implementation("io.ktor:ktor-client-core:3.0.3")
implementation("io.ktor:ktor-client-darwin:3.0.3")
implementation("io.ktor:ktor-serialization-kotlinx-json:3.0.3")

// JSON parsing (NewPipe compat)
implementation("com.github.TeamNewPipe:nanojson:...")
implementation("org.jsoup:jsoup:1.22.2")
implementation("org.mozilla:rhino:1.8.1")

// QuickJS for style plugins
implementation("io.github.dokar3:quickjs-kt-core:1.0.5")
```

### iOS Dependencies (CocoaPods)
```ruby
# Compose Multiplatform framework
pod 'ComposeApp', :path => '../shared'

# Image loading
pod 'SDWebImage', '~> 5.18'
pod 'SDWebImageSwiftUI', '~> 2.2'

# AudioKit for advanced audio processing
pod 'AudioKit', '~> 5.5'

# Networking
pod 'Alamofire', '~> 5.8'

# Database
pod 'GRDB.swift', '~> 6.27'
```

## Development Roadmap

### Phase 1: Core Playback (Current)
- [x] Basic AVFoundation player
- [x] Queue management
- [x] Background audio
- [x] Now Playing UI
- [x] Mini player

### Phase 2: YouTube Music Integration
- [ ] Innertube client port to Swift/Kotlin
- [ ] NewPipeExtractor Swift port or backend service
- [ ] Search, browse, radio
- [ ] Stream URL resolution

### Phase 3: Smart Features
- [ ] Core ML models for beat tracking
- [ ] Vocal separation (ONNX → Core ML)
- [ ] Automix implementation
- [ ] Harmonic analysis

### Phase 4: Platform Features
- [ ] Widgets (Lock Screen, Home Screen)
- [ ] Shortcuts / Siri integration
- [ ] CarPlay support
- [ ] SharePlay (Listen Together)

### Phase 5: Polish
- [ ] Offline downloads with metadata
- [ ] Equalizer presets
- [ ] Dynamic theming
- [ ] Performance optimization
- [ ] Accessibility
- [ ] Localization

## License

GPLv3 - Same as the original Android app.

## Credits

Original Android app by [kushagrasinghx](https://github.com/kushagrasinghx/BitChord)
iOS port - Kotlin Multiplatform + SwiftUI implementation