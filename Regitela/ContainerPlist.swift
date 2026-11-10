import Foundation

enum ContainerPlistError: LocalizedError {
    case noAccess(Int64)
    case notADictionary

    var errorDescription: String? {
        switch self {
        case .noAccess(let handle):
            return "Couldn't get access to the container (handle \(handle))."
        case .notADictionary:
            return "The plist isn't a dictionary."
        }
    }
}

struct ContainerPlist {
    let container: String
    let relativePath: String

    var path: String { container + "/" + relativePath }

    func withAccess<T>(_ body: () throws -> T) throws -> T {
        let handle = issueSandboxExtension(for: container)
        guard handle > 0 else { throw ContainerPlistError.noAccess(handle) }
        defer { releaseSandboxExtension(handle) }
        print("extension class: \(worse_query_last_extension_class() ?? "unknown")")
        return try body()
    }

    func read() throws -> ([String: Any], PropertyListSerialization.PropertyListFormat) {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var format = PropertyListSerialization.PropertyListFormat.binary
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        guard let dict = object as? [String: Any] else { throw ContainerPlistError.notADictionary }
        return (dict, format)
    }

    // In place: an atomic write would also need write access to the directory
    func write(_ dict: [String: Any], format: PropertyListSerialization.PropertyListFormat) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)

        let fd = open(path, O_WRONLY | O_TRUNC)
        if fd < 0 { throw posixError("open") }
        defer { close(fd) }

        let written = data.withUnsafeBytes { buffer in
            Darwin.write(fd, buffer.baseAddress, buffer.count)
        }
        if written < 0 { throw posixError("write") }
    }

    private func posixError(_ syscall: String) -> NSError {
        let code = errno
        let name = String(cString: strerror(code))
        return NSError(domain: "worse_query.posix", code: Int(code), userInfo: [
            NSLocalizedDescriptionKey: "\(syscall)() failed: \(name) (errno \(code))"
        ])
    }

    func readData() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }

    func diagnostics() -> String {
        func describe(_ path: String) -> String {
            var st = stat()
            let name = (path as NSString).lastPathComponent
            guard lstat(path, &st) == 0 else { return "\(name): stat failed (errno \(errno))" }
            let flags = String(st.st_flags, radix: 16)
            return "\(name): uid \(st.st_uid) gid \(st.st_gid) mode \(String(st.st_mode & 0o7777, radix: 8)) flags 0x\(flags)"
        }
        return [describe(path),
                describe((path as NSString).deletingLastPathComponent),
                "app uid \(getuid()) gid \(getgid())",
                "extension class: \(worse_query_last_extension_class() ?? "unknown")"].joined(separator: "\n")
    }
}

func describeError(_ error: Error) -> String {
    let nsError = error as NSError
    var text = "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
        text += " [\(underlying.domain) \(underlying.code)]"
    }
    return text
}
