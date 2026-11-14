import Foundation

// Kernel r/w backend (darksword-kexploit-fun, used with permission): one
// exploit patches this process's sandbox to root r/w for its lifetime,
// reaching ConfigurationProfiles (Supervised Mode) on iOS 26 where geod can't.
final class KernelAccess: SystemFileAccess {
    let name = "darksword kernel"

    var isAvailable: Bool { regitela_kernel_available() }

    // geod is read-only here: ConfigurationProfiles EPERMs outright and
    // MobileGestalt writes are denied, so claim both groups for the kernel.
    func canAccess(_ path: String) -> Bool {
        guard isAvailable else { return false }
        return path.contains("systemgroup.com.apple.configurationprofiles")
            || path.contains("systemgroup.com.apple.mobilegestaltcache")
    }

    // Only succeeds once unlocked from the Unlock screen; never runs the exploit
    // itself, so tapping a tweak can't silently trigger it.
    func acquire(_ path: String) -> Int64 {
        guard regitela_kernel_is_unlocked() else { return -6 }
        return kernelHandleBase // process-wide patch; no per-path resource
    }

    func release(_ handle: Int64) {} // patch persists for the process lifetime
}
