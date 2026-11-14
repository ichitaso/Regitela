import SwiftUI

// Dopamine-style screen that runs the kernel exploit up front, with a live log,
// so the pause on first use of a kernel-only feature isn't a silent freeze.
struct UnlockView: View {
    @ObservedObject var console: Console

    private enum Phase { case idle, running, done, failed }
    @State private var phase: Phase = regitela_kernel_is_unlocked() ? .done : .idle

    private let accent = Color(red: 0.30, green: 0.85, blue: 0.39)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                Image(systemName: phase == .done ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(phase == .failed ? .red : accent)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if phase != .idle {
                    terminal
                }

                Spacer(minLength: 24)
                button
            }
            .padding()
        }
        .navigationTitle("Kernel Access")
        .navigationBarTitleDisplayMode(.inline)
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
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(accent.opacity(0.25)))
    }

    private var button: some View {
        Button(action: unlock) {
            HStack(spacing: 8) {
                if phase == .running { ProgressView().tint(.black) }
                Text(buttonTitle).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(phase == .done ? Color.gray.opacity(0.3) : accent)
            .foregroundStyle(phase == .done ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(phase == .running || phase == .done)
    }

    private func unlock() {
        phase = .running
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = regitela_kernel_unlock()
            DispatchQueue.main.async { phase = ok ? .done : .failed }
        }
    }

    private var title: String {
        switch phase {
        case .idle, .running: return String(localized: "Kernel Access")
        case .done: return String(localized: "Unlocked")
        case .failed: return String(localized: "Failed")
        }
    }

    private var subtitle: String {
        switch phase {
        case .idle: return String(localized: "Unlock once to read and write system files. This runs a kernel exploit and takes a few seconds.")
        case .running: return String(localized: "Running the kernel exploit…")
        case .done: return String(localized: "System files are read/write for this session. The tweaks now apply instantly.")
        case .failed: return String(localized: "The kernel exploit didn't succeed. You can try again.")
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .idle: return String(localized: "Unlock")
        case .running: return String(localized: "Unlocking…")
        case .done: return String(localized: "Unlocked")
        case .failed: return String(localized: "Try Again")
        }
    }
}
