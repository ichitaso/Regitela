import SwiftUI
import Combine

// Shared kernel-unlock state so Home can reveal the tweaks once unlocked.
final class KernelState: ObservableObject {
    @Published var unlocked = regitela_kernel_is_unlocked()
    @Published var running = false
    @Published var failed = false

    func unlock() {
        guard !running, !unlocked else { return }
        running = true
        failed = false
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = regitela_kernel_unlock()
            DispatchQueue.main.async {
                self.running = false
                self.unlocked = ok
                self.failed = !ok
            }
        }
    }
}

// Dopamine-style gate: run the kernel exploit once, with a live log, before the
// kernel-only tweaks become available. The exploit runs only from here.
struct UnlockView: View {
    @ObservedObject var console: Console
    @ObservedObject var kernel: KernelState
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.30, green: 0.85, blue: 0.39)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: kernel.unlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(kernel.failed ? .red : accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                if !kernel.unlocked {
                    actionButton(title: buttonTitle, filled: !kernel.running) { kernel.unlock() }
                        .disabled(kernel.running)
                }

                terminal

                if kernel.unlocked {
                    actionButton(title: String(localized: "Done"), filled: true) { dismiss() }
                }
            }
            .padding()
        }
        .navigationTitle("Kernel Access")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(kernel.running)
    }

    private var terminal: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(console.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(accent)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .id("end")
            }
            .onChange(of: console.output) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
        }
        .frame(maxHeight: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(accent.opacity(0.25)))
    }

    private func actionButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if kernel.running { ProgressView().tint(.black) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(filled ? accent : Color.gray.opacity(0.3))
            .foregroundStyle(filled ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var title: String {
        if kernel.unlocked { return String(localized: "Unlocked") }
        if kernel.failed { return String(localized: "Failed") }
        return String(localized: "Kernel Access")
    }

    private var buttonTitle: String {
        if kernel.running { return String(localized: "Unlocking…") }
        if kernel.failed { return String(localized: "Try Again") }
        return String(localized: "Unlock")
    }
}
