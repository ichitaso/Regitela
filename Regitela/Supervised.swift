import SwiftUI

// An extension for the whole container can't write in ConfigurationProfiles, so it's issued for the directory itself
private let supervisedPlist = ContainerPlist(
    container: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles",
    relativePath: "CloudConfigurationDetails.plist"
)
private let supervisedKey = "IsSupervised"

struct SupervisedView: View {
    private enum Mode { case unknown, on, off }

    @State private var mode: Mode = .unknown
    @State private var status: String?
    @State private var failed = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Supervised Mode")
                    Spacer()
                    Text(modeText)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(supervisedPlist.path)
                    .font(.caption)
            }

            Section {
                Button("Enable") { apply(true) }
                    .disabled(mode == .on)
                Button("Disable", role: .destructive) { apply(false) }
                    .disabled(mode == .off)
                Button("Refresh") { refresh() }
            } footer: {
                Text("Don't use this if the device is already managed by MDM. A setup screen may appear after the next respring or reboot. Quit the Settings app to apply.")
                    .font(.caption)
            }

            if let status {
                Section {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(failed ? .red : .secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Supervised Mode")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private var modeText: LocalizedStringKey {
        switch mode {
        case .unknown: return "Unknown"
        case .on: return "ON"
        case .off: return "OFF"
        }
    }

    private func report(_ message: String, failed: Bool) {
        status = message
        self.failed = failed
        print("supervised: " + message)
    }

    private func refresh() {
        do {
            let enabled = try supervisedPlist.withAccess {
                let (dict, _) = try supervisedPlist.read()
                return (dict[supervisedKey] as? Bool) ?? false
            }
            mode = enabled ? .on : .off
            status = nil
        } catch {
            mode = .unknown
            report(String(localized: "Failed to read: \(describeError(error))"), failed: true)
        }
    }

    private func apply(_ enabled: Bool) {
        do {
            try supervisedPlist.withAccess {
                var (dict, format) = try supervisedPlist.read()
                if enabled {
                    dict[supervisedKey] = true
                } else {
                    dict.removeValue(forKey: supervisedKey)
                }
                do {
                    try supervisedPlist.write(dict, format: format)
                } catch {
                    throw NSError(domain: "Regitela", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: describeError(error) + "\n" + supervisedPlist.diagnostics()
                    ])
                }
            }
            mode = enabled ? .on : .off
            report(enabled ? String(localized: "Set to ON. Quit the Settings app to apply.") : String(localized: "Set to OFF. Quit the Settings app to apply."), failed: false)
        } catch {
            report(String(localized: "Failed to write: \(error.localizedDescription)"), failed: true)
        }
    }
}
