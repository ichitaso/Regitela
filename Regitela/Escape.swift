import UIKit

let accessibleGroup: String? = worse_query_group()

// Installed from the rootless .deb: no sandbox, so extensions aren't needed
let isUnsandboxed = (try? FileManager.default.contentsOfDirectory(atPath: "/private/var/containers/Shared/SystemGroup")) != nil

private let unsandboxedHandle = Int64.max
private let geodHandleBase: Int64 = 0x4000000000

func issueSandboxExtension(for path: String) -> Int64 {
    if isUnsandboxed {
        return unsandboxedHandle
    }

    let handle = issueUserspaceExtension(for: path)
    if handle > 0 {
        return handle
    }

    // Userspace couldn't reach it; fall back to a kernel backend if registered.
    if let backend = kernelAccess, backend.isAvailable, backend.canAccess(path) {
        let kernelHandle = backend.acquire(path)
        if kernelHandle > 0 {
            print("access via \(backend.name): \(path)")
            return kernelHandle
        }
    }

    return handle
}

private func issueUserspaceExtension(for path: String) -> Int64 {
    // iOS 26 can't reach SystemGroup via an App Group; use the geod route instead.
    if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
        && path.contains("/containers/Shared/SystemGroup") {
        let handle = geod_query(path)
        print("geod handle: \(handle)")
        if handle >= geodHandleBase {
            print("geod granted path: \(geod_last_path() ?? "unknown")")
        }
        return handle
    }

    guard let group = accessibleGroup else {
        print("no accessible app group! (check the app group entitlement)")
        return -1
    }

    var handle: Int64 = -255
    if path.contains("/var/mobile/Containers/Shared/AppGroup") && ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26 {
        handle = worse_query(path, group, true, false)
    } else {
        handle = worse_query(path, group, false, false)
    }

    switch handle {
    case -1:
        print("failed to access group!")
    case -2:
        print("failed to resolve functions!")
    case -3:
        print("failed to create query!")
    case -4:
        print("failed to create symlink!")
    case -5:
        print("query rejected!")
    case -6:
        print("kernel refused extension issue!")
    case -255:
        print("target doesn't exist!")
    default:
        print("handle: \(handle)")
    }
    return handle
}

let appDisplayNames: [String: String] = (copyBundleDisplayNames() as? [String: String]) ?? [:]

func containerIdentifier(atPath path: String) -> String? {
    var buffer = [CChar](repeating: 0, count: 512)
    let length = getxattr(path, "com.apple.containermanager.identifier", &buffer, 511, 0, 0)
    guard length > 0 else { return nil }
    return String(cString: buffer)
}

private var displayNameCache: [String: String?] = [:]
private var loggedNameMethod = false

func displayName(forIdentifier identifier: String) -> String? {
    if let name = appDisplayNames[identifier] { return name }
    if let cached = displayNameCache[identifier] { return cached }
    if identifier.hasPrefix("group.") || identifier.hasPrefix("systemgroup.") {
        displayNameCache[identifier] = .some(nil)
        return nil
    }
    var method: NSString?
    let name = copyDisplayNameForBundleID(identifier, &method)
    if let name, let method, !loggedNameMethod {
        loggedNameMethod = true
        print("app names: resolved via \(method)")
    }
    displayNameCache[identifier] = .some(name)
    return name
}

private var iconCache: [String: UIImage?] = [:]

func appIcon(forIdentifier identifier: String) -> UIImage? {
    if let cached = iconCache[identifier] { return cached }
    let icon = displayName(forIdentifier: identifier) != nil ? copyIconForBundleID(identifier) : nil
    iconCache[identifier] = .some(icon)
    return icon
}

func containerLabel(forIdentifier identifier: String) -> String {
    if let name = displayName(forIdentifier: identifier) {
        return "\(name) (\(identifier))"
    }
    return identifier
}

func releaseSandboxExtension(_ handle: Int64) {
    if handle < 0 {
        print("sandbox extension hasn't been consumed!")
        return
    }
    if handle == unsandboxedHandle {
        return
    }
    if handle >= kernelHandleBase {
        kernelAccess?.release(handle)
        print("released kernel access!")
        return
    }
    if handle >= geodHandleBase {
        geod_release(handle)
        print("released geod extension!")
        return
    }
    worse_query_release(handle)
    print("released sandbox extension!")
}
