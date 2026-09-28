import Foundation
import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var colorSchemeOption: ColorSchemeOption = .system {
        didSet {
            UserDefaults.standard.set(colorSchemeOption.rawValue, forKey: "theme.colorScheme")
        }
    }
    
    @Published var isDynamicThemingEnabled = true {
        didSet {
            UserDefaults.standard.set(isDynamicThemingEnabled, forKey: "theme.dynamicTheming")
        }
    }
    
    @Published var currentAlbumColors: AlbumColors?
    
    var colorScheme: ColorScheme? {
        switch colorSchemeOption {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: "theme.colorScheme"),
           let option = ColorSchemeOption(rawValue: raw) {
            colorSchemeOption = option
        }
        isDynamicThemingEnabled = UserDefaults.standard.bool(forKey: "theme.dynamicTheming")
    }
    
    func updateAlbumColors(from image: UIImage) {
        guard isDynamicThemingEnabled else { return }
        
        Task {
            let colors = await extractColors(from: image)
            await MainActor.run {
                self.currentAlbumColors = colors
            }
        }
    }
    
    func clearAlbumColors() {
        currentAlbumColors = nil
    }
    
    private func extractColors(from image: UIImage) async -> AlbumColors {
        // Use Core Image to extract dominant colors
        // This is a simplified version
        let dominant = extractDominantColor(from: image)
        let vibrant = extractVibrantColor(from: image)
        let muted = extractMutedColor(from: image)
        
        return AlbumColors(
            primary: Color(dominant),
            secondary: Color(vibrant),
            background: Color(muted),
            onPrimary: Color(contrastingColor(for: dominant)),
            onSecondary: Color(contrastingColor(for: vibrant)),
            onBackground: Color(contrastingColor(for: muted))
        )
    }
    
    private func extractDominantColor(from image: UIImage) -> UIColor {
        // Simple average color extraction
        guard let cgImage = image.cgImage else { return .systemBackground }
        
        let width = 50
        let height = 50
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        var count = 0
        
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let alpha = pixelData[i + 3]
            if alpha > 128 {
                red += CGFloat(pixelData[i]) / 255.0
                green += CGFloat(pixelData[i + 1]) / 255.0
                blue += CGFloat(pixelData[i + 2]) / 255.0
                count += 1
            }
        }
        
        if count > 0 {
            red /= CGFloat(count)
            green /= CGFloat(count)
            blue /= CGFloat(count)
        }
        
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    private func extractVibrantColor(from image: UIImage) -> UIColor {
        // Simplified - in production use a proper color quantization algorithm
        extractDominantColor(from: image)
    }
    
    private func extractMutedColor(from image: UIImage) -> UIColor {
        let dominant = extractDominantColor(from: image)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        dominant.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s * 0.3, brightness: b * 0.8, alpha: a)
    }
    
    private func contrastingColor(for color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5 ? .black : .white
    }
}

// MARK: - Models
enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct AlbumColors {
    let primary: Color
    let secondary: Color
    let background: Color
    let onPrimary: Color
    let onSecondary: Color
    let onBackground: Color
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary, background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var meshGradient: some View {
        // iOS 17+ MeshGradient would go here
        Rectangle().fill(gradient)
    }
}

// MARK: - View Extensions
extension View {
    func albumThemed(_ colors: AlbumColors?) -> some View {
        self.background(colors?.background ?? Color(.systemBackground))
            .foregroundColor(colors?.onBackground ?? Color(.label))
    }
    
    func primaryThemed(_ colors: AlbumColors?) -> some View {
        self.background(colors?.primary ?? Color.accentColor)
            .foregroundColor(colors?.onPrimary ?? .white)
    }
}