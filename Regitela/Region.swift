import SwiftUI

// Regions to switch to: ISO country code (for the display name), RegionCode and RegionInfo
private struct TargetRegion: Hashable {
    let country: String
    let code: String
    var region: String { code + "/A" }
    var name: String { Locale.current.localizedString(forRegionCode: country) ?? country }
}

private let targetRegions = [
    TargetRegion(country: "US", code: "LL"),
    TargetRegion(country: "JP", code: "J"),
    TargetRegion(country: "CN", code: "CH"),
    TargetRegion(country: "HK", code: "ZP"),
    TargetRegion(country: "TW", code: "TA"),
    TargetRegion(country: "KR", code: "KH"),
    TargetRegion(country: "GB", code: "B"),
    TargetRegion(country: "DE", code: "D"),
    TargetRegion(country: "FR", code: "FN"),
    TargetRegion(country: "CA", code: "C"),
    TargetRegion(country: "AU", code: "X"),
    TargetRegion(country: "SG", code: "ZA"),
    TargetRegion(country: "IN", code: "HN"),
    TargetRegion(country: "VN", code: "VN"),
]

let gestaltPlist = ContainerPlist(
    container: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache",
    relativePath: "Library/Caches/com.apple.MobileGestalt.plist"
)
private let countryKey = "h63QSdBCiT/z0WU6rdQv6Q"
// RegionInfo lives under one of these keys depending on the device. Only an existing key is
// changed: adding one that isn't there makes iOS 27 rebuild the cache at boot.
private let regionKeys = ["zHeENZu+wbg7PUprwNwBWg", "yK+xavymRGZ3xWc1tb8XDg"]

private func regionKey(in extra: [String: Any]) -> String? {
    regionKeys.first { extra[$0] != nil }
}

private let backupDefaultsKey = "RegionBackup"
private var fullBackupURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MobileGestalt-original.plist")
}

func readGestaltExtra() throws -> [String: Any] {
    try gestaltPlist.withAccess {
        let (dict, _) = try gestaltPlist.read()
        return dict["CacheExtra"] as? [String: Any] ?? [:]
    }
}

// Saves a copy of the untouched cache before the first change
func modifyGestaltExtra(_ change: (inout [String: Any]) throws -> Void) throws {
    try gestaltPlist.withAccess {
        var (dict, format) = try gestaltPlist.read()
        if !FileManager.default.fileExists(atPath: fullBackupURL.path) {
            try gestaltPlist.readData().write(to: fullBackupURL)
        }
        var extra = dict["CacheExtra"] as? [String: Any] ?? [:]
        try change(&extra)
        dict["CacheExtra"] = extra
        do {
            try gestaltPlist.write(dict, format: format)
        } catch {
            throw NSError(domain: "Regitela", code: 1, userInfo: [
                NSLocalizedDescriptionKey: describeError(error) + "\n" + gestaltPlist.diagnostics()
            ])
        }
    }
}

struct RegionView: View {
    @State private var country: String?
    @State private var region: String?
    @State private var loaded = false
    @State private var modified: Date?
    @State private var status: String?
    @State private var failed = false

    private var hasBackup: Bool {
        UserDefaults.standard.dictionary(forKey: backupDefaultsKey) != nil
    }

    @State private var hasRegionKey = false
    @AppStorage("RegionTarget") private var targetCode = "LL"

    private var target: TargetRegion {
        targetRegions.first { $0.code == targetCode } ?? targetRegions[0]
    }

    private var isApplied: Bool {
        country == target.code && (!hasRegionKey || region == target.region)
    }

    var body: some View {
        Form {
            Section("Current") {
                LabeledContent("Region Code", value: loaded ? (country ?? String(localized: "(none)")) : String(localized: "Unknown"))
                LabeledContent("Region", value: loaded ? (region ?? String(localized: "(none)")) : String(localized: "Unknown"))
                LabeledContent("Backup", value: hasBackup ? String(localized: "Saved (changed by this app)") : String(localized: "None"))
                if let modified {
                    LabeledContent("Cache modified", value: modified.formatted(date: .abbreviated, time: .standard))
                    if let boot = bootTime() {
                        LabeledContent("Last boot", value: boot.formatted(date: .abbreviated, time: .standard))
                    }
                }
            }

            Section {
                Picker("Region", selection: $targetCode) {
                    ForEach(targetRegions, id: \.code) { Text(verbatim: "\($0.name) (\($0.region))").tag($0.code) }
                }
                Button("Change Region to \(target.name) (\(target.region))") { apply() }
                    .disabled(!loaded || isApplied)
                Button("Restore Original", role: .destructive) { restore() }
                    .disabled(!loaded || !hasBackup)
                Button("Refresh") { refresh() }
            } footer: {
                Text("A reboot is required to apply the change. The original values are backed up before the first change, and a copy of the untouched cache is saved to this app's Documents folder.")
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

            Section {
                Text(gestaltPlist.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Region")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func report(_ message: String, failed: Bool) {
        status = message
        self.failed = failed
        print("region: " + message)
    }

    private func refresh() {
        do {
            let (extra, date) = try gestaltPlist.withAccess {
                let (dict, _) = try gestaltPlist.read()
                let attrs = try? FileManager.default.attributesOfItem(atPath: gestaltPlist.path)
                return (dict["CacheExtra"] as? [String: Any] ?? [:], attrs?[.modificationDate] as? Date)
            }
            modified = date
            country = extra[countryKey] as? String
            hasRegionKey = regionKey(in: extra) != nil
            region = regionKey(in: extra).flatMap { extra[$0] as? String }
            loaded = true
        } catch {
            loaded = false
            report(String(localized: "Failed to read: \(describeError(error))"), failed: true)
        }
    }

    private func apply() {
        do {
            try modifyGestaltExtra { extra in
                var changes = [countryKey: target.code]
                if let key = regionKey(in: extra) { changes[key] = target.region }
                // Record each key's original value the first time it is changed ("" = it was absent)
                var backup = UserDefaults.standard.dictionary(forKey: backupDefaultsKey) as? [String: String] ?? [:]
                for key in changes.keys where backup[key] == nil {
                    backup[key] = extra[key] as? String ?? ""
                }
                UserDefaults.standard.set(backup, forKey: backupDefaultsKey)
                extra.merge(changes) { _, new in new }
            }
            report(String(localized: "Changed to \(target.name) (\(target.region)). Reboot to apply."), failed: false)
        } catch {
            report(String(localized: "Failed to change: \(error.localizedDescription)"), failed: true)
        }
        refresh()
    }

    private func restore() {
        guard let backup = UserDefaults.standard.dictionary(forKey: backupDefaultsKey) as? [String: String] else { return }
        do {
            try modifyGestaltExtra { extra in
                for (key, value) in backup {
                    extra[key] = value.isEmpty ? nil : value
                }
            }
            UserDefaults.standard.removeObject(forKey: backupDefaultsKey)
            report(String(localized: "Restored the original region. Reboot to apply."), failed: false)
        } catch {
            report(String(localized: "Failed to restore: \(error.localizedDescription)"), failed: true)
        }
        refresh()
    }
}

private func bootTime() -> Date? {
    var tv = timeval()
    var size = MemoryLayout<timeval>.size
    var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
    guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
}
