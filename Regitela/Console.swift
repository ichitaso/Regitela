import Foundation
import Combine

class Console: ObservableObject {
    @Published var output = ""
    
    private var pipe: Pipe?
    private var originalOut: Int32 = 0
    
    func start() {
        // Redirecting stdout twice would leave originalOut on a dead pipe (SIGPIPE)
        guard pipe == nil else { return }
        signal(SIGPIPE, SIG_IGN)

        let newPipe = Pipe()
        pipe = newPipe
        originalOut = dup(STDOUT_FILENO)
        
        dup2(newPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        setvbuf(stdout, nil, _IONBF, 0)
        
        newPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            
            if let self = self {
                data.withUnsafeBytes { rawBuffer in
                    _ = write(self.originalOut, rawBuffer.baseAddress, data.count)
                }
            }
            
            if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                DispatchQueue.main.async {
                    self?.output += string
                }
            }
        }
        
        print("hello world (again)")
    }
}
