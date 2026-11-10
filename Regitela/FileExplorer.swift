import SwiftUI
import Combine
import UniformTypeIdentifiers

final class SandboxSession: ObservableObject {
    let handle: Int64
    let path: String

    init(path: String) {
        self.path = path
        handle = issueSandboxExtension(for: path)
    }

    var isValid: Bool { handle > 0 }

    deinit {
        if handle > 0 { releaseSandboxExtension(handle) }
    }
}

struct FileExplorerView: View {
    @StateObject private var session: SandboxSession
    private let root: String

    init(root: String) {
        var cleaned = root
        while cleaned.count > 1 && cleaned.hasSuffix("/") {
            cleaned.removeLast()
        }
        self.root = cleaned
        _session = StateObject(wrappedValue: SandboxSession(path: cleaned))
    }

    var body: some View {
        Group {
            if session.isValid {
                DirectoryView(path: root)
            } else {
                ContentUnavailableView(
                    "No Access",
                    systemImage: "lock.slash",
                    description: Text("Couldn't consume a sandbox extension for:\n\(root)\n\nCheck the Log tab for the reason.")
                )
            }
        }
    }
}

struct DirectoryView: View {
    let path: String

    struct Entry: Identifiable, Hashable {
        let url: URL
        let name: String
        let isDir: Bool
        let size: Int64
        let identifier: String?
        
        var title: String {
            guard let identifier else { return name }
            return displayName(forIdentifier: identifier) ?? identifier
        }
        
        var subtitle: String? {
            guard let identifier else { return nil }
            if displayName(forIdentifier: identifier) != nil {
                return identifier + "\n" + name
            }
            return name
        }
        var id: String { url.path }
    }

    @State private var entries: [Entry] = []
    @State private var error: String?
    @State private var newFileName = ""
    @State private var showingNewFile = false

    var body: some View {
        List {
            if let error {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if entries.isEmpty && error == nil {
                    Text("Empty directory")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    row(for: entry)
                }
                .onDelete(perform: delete)
            } footer: {
                if !entries.isEmpty {
                    Text("\(entries.count) item(s)")
                }
            }
        }
        .navigationTitle(directoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newFileName = ""
                        showingNewFile = true
                    } label: {
                        Label("New Text File", systemImage: "doc.badge.plus")
                    }
                    Button {
                        load()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("New Text File", isPresented: $showingNewFile) {
            TextField("Name", text: $newFileName)
                .textInputAutocapitalization(.never)
            Button("Create", action: createFile)
            Button("Cancel", role: .cancel) { }
        }
        .onAppear(perform: load)
        .refreshable { load() }
    }

    @ViewBuilder
    private func row(for entry: Entry) -> some View {
        if entry.isDir {
            NavigationLink {
                DirectoryView(path: entry.url.path)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                        if let subtitle = entry.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "folder.fill")
                }
            }
        } else {
            NavigationLink {
                FileEditorView(url: entry.url)
            } label: {
                HStack {
                    Label(entry.name, systemImage: "doc")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var directoryTitle: String {
        if let identifier = containerIdentifier(atPath: path) {
            return displayName(forIdentifier: identifier) ?? identifier
        }
        return (path as NSString).lastPathComponent
    }

    private func load() {
        let files = FileManager.default
        do {
            let names = try files.contentsOfDirectory(atPath: path)
            var list: [Entry] = []
            for name in names {
                let full = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                files.fileExists(atPath: full, isDirectory: &isDir)
                let attrs = try? files.attributesOfItem(atPath: full)
                let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                let identifier = isDir.boolValue ? containerIdentifier(atPath: full) : nil
                list.append(Entry(url: URL(fileURLWithPath: full),
                                  name: name,
                                  isDir: isDir.boolValue,
                                  size: size,
                                  identifier: identifier))
            }
            entries = list.sorted {
                ($0.isDir ? 0 : 1, $0.title.lowercased()) < ($1.isDir ? 0 : 1, $1.title.lowercased())
            }
            error = nil
        } catch {
            self.error = String(localized: "Failed to read directory: \(error.localizedDescription)")
            entries = []
        }
    }

    private func delete(at offsets: IndexSet) {
        let files = FileManager.default
        for index in offsets {
            let entry = entries[index]
            do {
                try files.removeItem(at: entry.url)
                print("deleted: \(entry.url.path)")
            } catch {
                self.error = String(localized: "Failed to delete \(entry.name): \(error.localizedDescription)")
            }
        }
        load()
    }

    private func createFile() {
        let name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let full = (path as NSString).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: full) {
            error = String(localized: "\(name) already exists")
            return
        }
        do {
            try "".write(toFile: full, atomically: true, encoding: .utf8)
            print("created: \(full)")
            load()
        } catch {
            self.error = String(localized: "Failed to create \(name): \(error.localizedDescription)")
        }
    }
}

struct FileEditorView: View {
    let url: URL

    @State private var text = ""
    @State private var original = ""
    @State private var loadError: String?
    @State private var isBinary = false
    @State private var byteCount: Int64 = 0
    @State private var status: String?

    private let maxEditableBytes: Int64 = 4_000_000

    private var isDirty: Bool { text != original }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Can't Open", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if isBinary {
                binaryView
            } else {
                editor
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isBinary && loadError == nil {
                    Button("Save", action: save)
                        .disabled(!isDirty)
                }
            }
        }
        .onAppear(perform: load)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            if let status {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 6)
            }
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private var binaryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.gearshape")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Not editable as text")
                .font(.headline)
            Text(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))
                .foregroundStyle(.secondary)
            ShareLink(item: url) {
                Label("Export / Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func load() {
        do {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            byteCount = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            if byteCount > maxEditableBytes {
                isBinary = true
                return
            }
            let data = try Data(contentsOf: url)
            if let string = String(data: data, encoding: .utf8) {
                text = string
                original = string
            } else {
                isBinary = true
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            original = text
            status = String(localized: "Saved \(Date().formatted(date: .omitted, time: .standard))")
            print("saved: \(url.path)")
        } catch {
            status = String(localized: "Save failed: \(error.localizedDescription)")
            print("save failed: \(url.path) — \(error.localizedDescription)")
        }
    }
}
