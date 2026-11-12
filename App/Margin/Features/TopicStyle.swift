import MarginCore
import SwiftUI

enum TopicStyle {
    static let icons = ["folder", "briefcase", "graduationcap", "lightbulb", "heart", "house", "globe", "book",
                        "hammer", "chart.line.uptrend.xyaxis", "dumbbell", "airplane", "music.note", "camera",
                        "cart", "leaf", "star", "flag", "chevron.left.forwardslash.chevron.right", "sparkles"]
    static let colors: [(name: String, color: Color)] = [
        ("sage", Color(red: 0.37, green: 0.49, blue: 0.35)),
        ("blue", Color(red: 0.24, green: 0.47, blue: 0.75)),
        ("amber", Color(red: 0.80, green: 0.55, blue: 0.18)),
        ("coral", Color(red: 0.82, green: 0.38, blue: 0.29)),
        ("plum", Color(red: 0.55, green: 0.36, blue: 0.62)),
        ("slate", Color(red: 0.42, green: 0.45, blue: 0.50)),
    ]

    static func color(_ name: String?) -> Color {
        colors.first { $0.name == name }?.color ?? Color(palette: Palette.accent)
    }
}

/// Popover to pick a topic's icon and color.
struct TopicAppearancePicker: View {
    let topic: Topic
    let onPick: (String?, String?) -> Void
    @State private var icon: String?
    @State private var color: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon and color").font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                ForEach(TopicStyle.colors, id: \.name) { c in
                    Circle().fill(c.color).frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(.white, lineWidth: color == c.name ? 2 : 0))
                        .shadow(color: color == c.name ? c.color.opacity(0.6) : .clear, radius: 3)
                        .onTapGesture { color = c.name; onPick(icon, color) }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 7), spacing: 6) {
                ForEach(TopicStyle.icons, id: \.self) { name in
                    Image(systemName: name)
                        .font(.system(size: 13))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(icon == name ? .white : TopicStyle.color(color))
                        .background(RoundedRectangle(cornerRadius: 7).fill(icon == name ? TopicStyle.color(color) : Color(palette: Palette.block)))
                        .onTapGesture { icon = name; onPick(icon, color) }
                }
            }
        }
        .padding(14)
        .onAppear { icon = topic.icon ?? "folder"; color = topic.color }
    }
}
