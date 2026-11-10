import SwiftUI

private struct FoundContainer: Identifiable {
    let path: String
    let identifier: String?
    var id: String { path }
}

private var scanCache: [String: [FoundContainer]] = [:]

struct ContainerListView: View {
    let parent: String

    @State private var containers: [FoundContainer] = []
    @State private var scanning = false
    @State private var scanned = false
    @State private var search = ""

    private var filtered: [FoundContainer] {
        guard !search.isEmpty else { return containers }
        return containers.filter {
            title(for: $0).localizedCaseInsensitiveContains(search)
                || ($0.identifier ?? "").localizedCaseInsensitiveContains(search)
                || $0.path.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            if scanning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning… this takes a while")
                        .foregroundStyle(.secondary)
                }
            } else if scanned && containers.isEmpty {
                Text("No containers found")
                    .foregroundStyle(.secondary)
            }

            ForEach(filtered) { container in
                NavigationLink {
                    FileExplorerView(root: container.path)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: container))
                        Text(subtitle(for: container))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $search)
        .navigationTitle((parent as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    scan(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(scanning)
            }
        }
        .onAppear { scan(force: false) }
    }

    private func title(for container: FoundContainer) -> String {
        guard let identifier = container.identifier else {
            return (container.path as NSString).lastPathComponent
        }
        return displayName(forIdentifier: identifier) ?? identifier
    }

    private func subtitle(for container: FoundContainer) -> String {
        let folder = (container.path as NSString).lastPathComponent
        if let identifier = container.identifier, displayName(forIdentifier: identifier) != nil {
            return identifier + "\n" + folder
        }
        return container.identifier == nil ? String(localized: "unidentified") : folder
    }

    private func scan(force: Bool) {
        guard !scanning else { return }
        if !force, let cached = scanCache[parent] {
            containers = cached
            scanned = true
            return
        }

        scanning = true
        let parent = self.parent
        DispatchQueue.global(qos: .userInitiated).async {
            let found = findContainers(in: parent)
            DispatchQueue.main.async {
                let sorted = found.sorted { title(for: $0).lowercased() < title(for: $1).lowercased() }
                scanCache[parent] = sorted
                containers = sorted
                scanning = false
                scanned = true
            }
        }
    }
}

private func findContainers(in parent: String) -> [FoundContainer] {
    let files = FileManager.default
    let baselineURL = files.temporaryDirectory.appendingPathComponent(".baseline_\(UUID().uuidString)")
    var baselineInode: UInt64 = 0
    do {
        try "helloworld".write(to: baselineURL, atomically: true, encoding: .utf8)
        var info = stat()
        if stat(baselineURL.path, &info) == 0 {
            baselineInode = info.st_ino
        }
        try? files.removeItem(at: baselineURL)
    } catch {
        print("containers: failed to get baseline inode: \(error)")
        return []
    }
    guard baselineInode > 0 else { return [] }

    print("containers: scanning \(parent)...")
    let paths = pathleak(parent, baselineInode) ?? []
    var found: [FoundContainer] = []
    for path in paths {
        let handle = issueSandboxExtension(for: path)
        guard handle > 0 else { continue }
        found.append(FoundContainer(path: path, identifier: containerIdentifier(atPath: path)))
        releaseSandboxExtension(handle)
    }
    print("containers: \(found.count) accessible of \(paths.count) found")
    return found
}
