import SwiftUI

struct ContentView: View {
    @StateObject private var console = Console()
    @State private var sandboxHandle: Int64?
    @State private var path = "/private/var/mobile/Containers/Shared/AppGroup/"
    private let group = accessibleGroup

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                AdvancedView(path: $path, sandboxHandle: $sandboxHandle)
            }
            .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }

            NavigationStack {
                LogView(console: console)
            }
            .tabItem { Label("Log", systemImage: "text.alignleft") }
        }
        .onAppear() {
            console.start()
            print("app group: \(group ?? "none")")
            if isUnsandboxed {
                print("sandbox: none (jailbreak), extensions not needed")
            }
            print("app names: \(appDisplayNames.count) enumerated")
        }
    }
}

// Keep the /private prefix: fsgetpath returns it and pathleak matches on it.
// parentAccess: the directory itself can get an extension on iOS 27; otherwise only its children can.
typealias Preset = (path: String, iOS27Only: Bool, parentAccess: Bool)
let presetPaths: [Preset] = [
    ("/private/var/containers/Data/System/", true, true),
    ("/private/var/containers/Shared/SystemGroup/", true, false),
    ("/private/var/mobile/Containers/Data/Application/", false, false),
    ("/private/var/mobile/Containers/Data/InternalDaemon/", false, false),
    ("/private/var/mobile/Containers/Data/PluginKitPlugin/", false, false),
    ("/private/var/mobile/Containers/Shared/AppGroup/", false, true),
]
let isIOS27 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27

let directPresets = isUnsandboxed ? presetPaths : presetPaths.filter { $0.parentAccess && isIOS27 }

let targetPresets = isIOS27 || isUnsandboxed ? directPresets : presetPaths.filter { !$0.iOS27Only }

let leakOnlyPresets = isUnsandboxed ? [] : presetPaths.filter { (!$0.iOS27Only || isIOS27) && !($0.parentAccess && isIOS27) }

private struct HomeView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Regitela")
                            .font(.custom("HelveticaNeue-UltraLight", size: 32))
                            .tracking(1.5)
                        Text(version)
                            .font(.custom("HelveticaNeue-Light", size: 13))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            }

            Section("Tweaks") {
                NavigationLink {
                    SupervisedView()
                } label: {
                    Label("Supervised Mode", systemImage: "checkmark.shield")
                }
                NavigationLink {
                    RegionView()
                } label: {
                    Label("Region", systemImage: "globe")
                }
                ForEach(GestaltFeature.all.filter(\.isVisible)) { feature in
                    NavigationLink {
                        GestaltFeatureView(feature: feature)
                    } label: {
                        Label(feature.title, systemImage: feature.icon)
                    }
                }
            }
            
            if !directPresets.isEmpty {
                Section("Browse") {
                    ForEach(directPresets, id: \.path) { preset in
                        NavigationLink {
                            FileExplorerView(root: preset.path)
                        } label: {
                            PathRow(path: preset.path)
                        }
                    }
                }
            }

            if !leakOnlyPresets.isEmpty {
                Section {
                    ForEach(leakOnlyPresets, id: \.path) { preset in
                        NavigationLink {
                            ContainerListView(parent: preset.path)
                        } label: {
                            PathRow(path: preset.path)
                        }
                    }
                } header: {
                    Text("Containers")
                } footer: {
                    Text("Finds the containers with pathleak, then opens the one you tap. The first scan takes a while.")
                }
            }

            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("How to Use", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("Regitela")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct LogView: View {
    @ObservedObject var console: Console

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(console.output)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("bottom")
            }
            .onChange(of: console.output) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Clear") {
                console.output = ""
                print("hello (again)")
            }
        }
    }
}

private struct PathRow: View {
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text((path as NSString).lastPathComponent)
            Text(path)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
