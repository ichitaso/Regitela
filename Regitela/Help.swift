import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section {
                Text("**Use this app at your own risk.** Editing or deleting system files can make apps or iOS misbehave. Back up anything important before changing it.")
                    .font(.callout)
            } header: {
                Label("Caution", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            topic("About", systemImage: "info.circle",
                  "Regitela uses the worse_query sandbox escape to read and change files outside its own sandbox, without a jailbreak. It works on iOS 26 and 27; Supervised Mode, Region and Browse need iOS 27. On a rootless jailbreak (iOS 17 or later), install the .deb instead: it runs without a sandbox, so every feature works. Based on worse_query by forcequit (GPLv3).")
            topic("Supervised Mode", systemImage: "checkmark.shield",
                  "Turns Supervised Mode on or off by editing CloudConfigurationDetails.plist. Quit the Settings app to apply the change. Don't use it on a device that is managed by MDM.")
            topic("Region", systemImage: "globe",
                  "Changes the country and region code in the MobileGestalt cache to US (LL/A). Reboot to apply; the change stays after later reboots. Restore Original puts back the values saved before the first change.")
            topic("Browse", systemImage: "folder",
                  "Opens the App Group and system containers directly. Tap a folder to open it or a text file to edit and save it. Swipe left to delete, and use the ••• menu to create a new text file.")
            topic("Containers", systemImage: "shippingbox",
                  "Finds the containers of apps, extensions and system services with pathleak, and lists them by app name or bundle ID. The first scan takes a while; the results are kept until the app quits. Tap one to browse it, or search by name.")
            topic("Advanced", systemImage: "wrench.and.screwdriver",
                  "The original worse_query tools, for any path. Enter a path in Target Path or choose a preset. Consume holds access to it until you tap Release, Browse / Edit Files opens it, and Share Contents shares it while access is held. Find Containers and List Folders print what is under it to the Log.")
            topic("Log", systemImage: "text.alignleft",
                  "Shows what the app is doing and why something failed. Long-press the text to copy it, and tap Clear to empty it.")
        }
        .navigationTitle("How to Use")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func topic(_ title: LocalizedStringKey, systemImage: String, _ text: LocalizedStringKey) -> some View {
        Section {
            Text(text)
                .font(.callout)
        } header: {
            Label(title, systemImage: systemImage)
        }
    }
}
