import SwiftUI

struct LockView: View {
    let lock: AppLock
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: AppLock.biometryName == "Face ID" ? "faceid" : "touchid")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color(palette: Palette.accent))
                .symbolEffect(.pulse, options: .repeating, isActive: appeared)
            Text("Margin is locked").font(.system(size: 18, weight: .semibold))
            Button { lock.unlock() } label: {
                Text("Unlock with \(AppLock.biometryName)").frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent).tint(Color(palette: Palette.accent)).controlSize(.large)
            .keyboardShortcut(.defaultAction)
            if lock.failed {
                Text("Couldn't verify. Try again.").font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(Color(palette: Palette.canvas))
        .onAppear { appeared = true; lock.unlock() }
    }
}
