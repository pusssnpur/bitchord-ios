import SwiftUI
import AVFoundation
import MediaPlayer

@main
struct BitChordIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var playerController = PlayerController.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerController)
                .environmentObject(authManager)
                .environmentObject(downloadManager)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    playerController.activate()
                }
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak playerController] _ in
            playerController?.playPause()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak playerController] _ in
            playerController?.playPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak playerController] _ in
            playerController?.next()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak playerController] _ in
            playerController?.previous()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak playerController] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                playerController?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak playerController] _ in
            playerController?.seekForward(15)
            return .success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak playerController] _ in
            playerController?.seekBackward(15)
            return .success
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure app appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        
        // Configure tab bar
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Scene setup if needed
    }
}