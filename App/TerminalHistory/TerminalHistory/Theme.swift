import SwiftUI
import THCore

struct ThemedMenuLabel: View {
    let variant: IconVariant
    let accent: Color

    var body: some View {
        Image(systemName: "terminal")
            .foregroundStyle(accent)
            .symbolRenderingMode(variant == .monochrome ? .monochrome : .hierarchical)
    }
}

extension Color {
    init(hex: String) {
        if hex == "system" { self = .accentColor; return }
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(s, radix: 16) ?? 0
        self = Color(
            red: Double((v >> 16) & 0xff) / 255.0,
            green: Double((v >> 8) & 0xff) / 255.0,
            blue: Double(v & 0xff) / 255.0
        )
    }
}
