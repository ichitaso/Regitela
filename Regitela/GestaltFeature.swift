import SwiftUI

// Device capability keys in the MobileGestalt cache. They are absent on devices without the
// feature; adding them survives a reboot (verified on iOS 26), and the feature shows up after it.
struct GestaltFeature: Identifiable {
    let title: LocalizedStringKey
    let icon: String
    let keys: [String]
    let footer: LocalizedStringKey
    // Set when this app added the keys, so Disable never removes keys the device had itself
    let addedDefaultsKey: String

    var id: String { addedDefaultsKey }

    // Hidden on devices that have the feature themselves, unless this app added the keys
    var isVisible: Bool {
        UserDefaults.standard.bool(forKey: addedDefaultsKey) || !MGGetBoolAnswer(keys[0] as CFString)
    }

    static let all = [chargeLimit, alwaysOn, tapToWake]

    static let chargeLimit = GestaltFeature(
        title: "Charge Limit",
        icon: "battery.75percent",
        keys: ["37NVydb//GP/GrhuTN+exg"], // DeviceSupports80ChargeLimit
        footer: "Adds the charge limit option to Settings > Battery > Charging. Reboot to apply. Whether charging actually stops at the limit depends on the device.",
        addedDefaultsKey: "ChargeLimitAdded"
    )

    static let alwaysOn = GestaltFeature(
        title: "Always On Display",
        icon: "clock",
        keys: ["2OOJf1VhaM7NxfRok3HbWQ", "j8/Omm6s1lsmTDFsXjsBfA"], // DeviceSupportsAlwaysOnDisplay, DeviceSupportsAlwaysOnTime
        footer: "Adds Always On Display to Settings > Display & Brightness. Reboot to apply. On a display that can't drop to a low refresh rate, it uses much more battery and can cause burn-in.",
        addedDefaultsKey: "AlwaysOnAdded"
    )

    static let tapToWake = GestaltFeature(
        title: "Tap to Wake",
        icon: "hand.tap",
        keys: ["yZf3GTRMGTuwSV/lD7Cagw"], // DeviceSupportsTapToWake
        footer: "Adds Tap to Wake to Settings > Accessibility > Touch. Reboot to apply.",
        addedDefaultsKey: "TapToWakeAdded"
    )
}

struct GestaltFeatureView: View {
    private enum Mode { case unknown, on, off }

    let feature: GestaltFeature

    @State private var mode: Mode = .unknown
    @State private var status: String?
    @State private var failed = false

    private var added: Bool {
        get { UserDefaults.standard.bool(forKey: feature.addedDefaultsKey) }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: feature.addedDefaultsKey) }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(feature.title)
                    Spacer()
                    Text(modeText)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(gestaltPlist.path)
                    .font(.caption)
            }

            Section {
                Button("Enable") { apply(true) }
                    .disabled(mode != .off)
                Button("Disable", role: .destructive) { apply(false) }
                    .disabled(mode != .on || !added)
                Button("Refresh") { refresh() }
            } footer: {
                Text(feature.footer)
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
        .navigationTitle(feature.title)
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
        print("\(feature.addedDefaultsKey): " + message)
    }

    private func refresh() {
        do {
            let extra = try readGestaltExtra()
            mode = feature.keys.allSatisfy { (extra[$0] as? Int) == 1 } ? .on : .off
            status = nil
        } catch {
            mode = .unknown
            report(String(localized: "Failed to read: \(describeError(error))"), failed: true)
        }
    }

    private func apply(_ enabled: Bool) {
        do {
            try modifyGestaltExtra { extra in
                for key in feature.keys {
                    extra[key] = enabled ? 1 : nil
                }
            }
            added = enabled
            mode = enabled ? .on : .off
            report(enabled ? String(localized: "Set to ON. Reboot to apply.") : String(localized: "Set to OFF. Reboot to apply."), failed: false)
        } catch {
            report(String(localized: "Failed to write: \(error.localizedDescription)"), failed: true)
        }
    }
}
