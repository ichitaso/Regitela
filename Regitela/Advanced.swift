import SwiftUI

struct AdvancedView: View {
    @Binding var path: String
    @Binding var sandboxHandle: Int64?

    @FocusState private var pathFocused: Bool
    private var target: String { path.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Target Path") {
                TextField("Target", text: $path, axis: .vertical)
                    .focused($pathFocused)
                    .onChange(of: path) { _, newValue in
                        // Return would insert a newline; strip it and dismiss instead
                        if newValue.contains("\n") {
                            path = newValue.replacingOccurrences(of: "\n", with: "")
                            pathFocused = false
                        }
                    }
                if !targetPresets.isEmpty {
                    Menu {
                        ForEach(targetPresets, id: \.path) { preset in
                            Button {
                                path = preset.path
                            } label: {
                                Text((preset.path as NSString).lastPathComponent)
                                Text(preset.path)
                            }
                        }
                    } label: {
                        Label("Choose Preset Path", systemImage: "list.bullet")
                    }
                }
            }
            .disabled(sandboxHandle ?? -255 > 0)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)

            Section {
                Button("Consume Sandbox Extension") {
                    sandboxHandle = consumeExtension(target)
                }
                .disabled(target.isEmpty)
                .disabled(sandboxHandle ?? -255 > 0)

                Button("Release Sandbox Extension") {
                    releaseExtension(sandboxHandle ?? -255)
                    sandboxHandle = -255
                }
                .disabled(sandboxHandle ?? -255 < 0)
            } header: {
                Text("Escape")
            } footer: {
                Text("Holds access to the Target Path until you release it. Share Contents needs this.")
            }

            Section("Utilities") {
                NavigationLink {
                    FileExplorerView(root: target)
                } label: {
                    Label("Browse / Edit Files", systemImage: "folder")
                }
                .disabled(target.isEmpty)
                ShareLink(item: URL(fileURLWithPath: target)) {
                    Text("Share Contents")
                }
                .disabled(target.isEmpty)
            }

            Section {
                Button("Find Containers (pathleak)") {
                    leakPaths(target)
                }
                .disabled(target.isEmpty)
                Button("List Folders (parentdir)") {
                    listPaths(target)
                }
                .disabled(target.isEmpty)
            } header: {
                Text("Enumeration")
            } footer: {
                Text("Prints what is under the Target Path to the Log tab. Find Containers searches by brute force and takes a while. List Folders is instant, but only works on a path that can be opened directly.")
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    func leakPaths(_ filter: String) {
        let files = FileManager.default
        let baselineURL = files.temporaryDirectory.appendingPathComponent(".baseline_\(UUID().uuidString)")
        var baselineInode: UInt64 = 0
        do {
            try "helloworld".write(to: baselineURL, atomically: true, encoding: .utf8)
            var baselineInfo = stat()
            let baselinePath = baselineURL.path

            if stat(baselinePath, &baselineInfo) == 0 {
                baselineInode = baselineInfo.st_ino
                print("baseline: \(baselineInode)")
            } else {
                print("Failed to get baseline inode!")
            }

            try files.removeItem(at: baselineURL)
        } catch {
            print("Failed to get baseline inode: \(error)")
            return
        }

        print("This is gonna take a while...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let paths = pathleak(filter, baselineInode) ?? []
            print(paths.count)
            for path in paths {
                let handle = issueExtension(path)
                if handle > 0 {
                    if let identifier = containerIdentifier(atPath: path) {
                        print()
                        print(containerLabel(forIdentifier: identifier) + ": " + path)
                        print()
                    }
                    releaseExtension(handle)
                }
            }
            print("Done!")
        }
    }

    func listPaths(_ path: String) {
        let reused = sandboxHandle ?? -255 > 0
        let handle = reused ? sandboxHandle ?? -255 : issueExtension(path)
        if handle < 0 {
            print("Failed to get parent directory extension!")
            return
        }

        let files = FileManager.default
        let root = URL(filePath: path)

        var collected: [String] = []

        do {
            let enumerated = try files.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

            for fileURL in enumerated {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    collected.append(fileURL.path)
                }
            }
        } catch {
            print("Failed to load enumerate directories!")
        }

        for path in collected {
            print(path)
            if let identifier = containerIdentifier(atPath: path) {
                print()
                print(containerLabel(forIdentifier: identifier) + ": " + path)
                print()
            }
        }

        if !reused {
            releaseExtension(handle)
        }
    }

    func consumeExtension(_ path: String) -> Int64 {
        if sandboxHandle ?? -255 > 0 {
            print("already consumed sandbox token!")
            return sandboxHandle ?? -255
        }
        return issueExtension(path)
    }

    func issueExtension(_ path: String) -> Int64 {
        return issueSandboxExtension(for: path)
    }

    func releaseExtension(_ handle: Int64) {
        releaseSandboxExtension(handle)
    }
}
