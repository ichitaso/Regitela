import SwiftUI

@main
struct RegitelaApp: App {
    init() {
        // Register only when the exploit is compiled in and supported, and
        // never when unsandboxed (jailbroken): direct /var access needs no exploit.
        if !isUnsandboxed && regitela_kernel_available() {
            kernelAccess = KernelAccess()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
