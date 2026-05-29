import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: TortoiseModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CPUCard(model: model)
            MemoryCard(model: model)

            Toggle(
                "Show percentage in menu bar",
                isOn: Binding(
                    get: { model.showsPercentageInMenuBar },
                    set: { model.setShowsPercentageInMenuBar($0) }
                )
            )

            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .disabled(model.isUpdatingLaunchAtLogin)

            Divider()

            HStack {
                Button("Refresh") {
                    model.refresh()
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

private struct MemoryCard: View {
    @ObservedObject var model: TortoiseModel

    var body: some View {
        let memory = model.metrics.memory

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Memory", systemImage: "memorychip")
                    .font(.headline)

                Spacer()

                AnimatedPercentageText(value: memory.usedFraction, fractionDigits: 1)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            HStack(spacing: 4) {
                AnimatedByteText(bytes: memory.usedBytes)
                Text("of \(byteString(memory.totalBytes)) in use")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let width = max(0, min(proxy.size.width * memory.usedFraction, proxy.size.width))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(Color(red: 0.17, green: 0.68, blue: 0.49))
                        .frame(width: width)
                        .animation(.easeOut(duration: 0.35), value: memory.usedFraction)
                }
            }
            .frame(height: 8)

            VStack(spacing: 8) {
                MemoryStatRow(title: "Active", bytes: memory.activeBytes)
                MemoryStatRow(title: "Wired", bytes: memory.wiredBytes)
                MemoryStatRow(title: "Compressed", bytes: memory.compressedBytes)
                MemoryStatRow(title: "Cached", bytes: memory.cachedBytes)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

}

private struct CPUCard: View {
    @ObservedObject var model: TortoiseModel

    var body: some View {
        let cpu = model.metrics.cpu

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("CPU", systemImage: "cpu")
                    .font(.headline)

                Spacer()

                AnimatedPercentageText(value: cpu.totalUsage, fractionDigits: 1)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            Text(model.runnerStateDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                CPUStatRow(title: "User", value: cpu.userUsage, tint: Color(red: 0.26, green: 0.53, blue: 0.91))
                CPUStatRow(title: "System", value: cpu.systemUsage, tint: Color(red: 0.97, green: 0.55, blue: 0.16))
                CPUStatRow(title: "Idle", value: cpu.idleUsage, tint: Color.secondary.opacity(0.65))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct MemoryStatRow: View {
    let title: String
    let bytes: UInt64

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            AnimatedByteText(bytes: bytes)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
        .font(.footnote)
    }
}

private struct CPUStatRow: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer()

                AnimatedPercentageText(value: value, fractionDigits: 1)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }
            .font(.footnote)

            GeometryReader { proxy in
                let width = max(0, min(proxy.size.width * value, proxy.size.width))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(tint)
                        .frame(width: width)
                        .animation(.easeOut(duration: 0.35), value: value)
                }
            }
            .frame(height: 8)
        }
    }
}

private func byteString(_ bytes: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.countStyle = .memory
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: Int64(bytes))
}

private struct AnimatedPercentageText: View {
    let value: Double
    let fractionDigits: Int

    var body: some View {
        AnimatedDisplayText(text: String(format: "%.\(fractionDigits)f%%", value * 100))
            .monospacedDigit()
    }
}

private struct AnimatedByteText: View {
    let bytes: UInt64

    var body: some View {
        AnimatedDisplayText(text: byteString(bytes))
            .monospacedDigit()
    }
}

private struct AnimatedDisplayText: View {
    let text: String

    var body: some View {
        ZStack {
            Text(text)
                .id(text)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -3)),
                    removal: .opacity
                ))
        }
        .animation(.easeOut(duration: 0.25), value: text)
    }
}
