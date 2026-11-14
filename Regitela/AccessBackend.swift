import Foundation

// A pluggable provider of access to files outside the app sandbox. The default
// routes are userspace (worse_query, geod); a kernel read/write backend can be
// registered at launch to reach paths they can't, such as ConfigurationProfiles
// on iOS 26. Exploit backends are licensed separately and aren't in this repo.
protocol SystemFileAccess {
    var name: String { get }
    var isAvailable: Bool { get }
    func canAccess(_ path: String) -> Bool
    func acquire(_ path: String) -> Int64   // handle >= kernelHandleBase, or negative error
    func release(_ handle: Int64)
}

// Above the geod handle range (0x4000000000), below unsandboxedHandle.
let kernelHandleBase: Int64 = 0x5000000000

// Set by a kernel backend when one is compiled in; nil in the public build.
var kernelAccess: SystemFileAccess?
