import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppearanceChoice.allCases) { Text($0.label).tag($0) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
