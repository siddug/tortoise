import AppKit
import Darwin
import Foundation
import ServiceManagement

@MainActor
final class TortoiseModel: ObservableObject {
    @Published private(set) var metrics: SystemMetricsSnapshot
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var isUpdatingLaunchAtLogin = false
    @Published private(set) var showsPercentageInMenuBar: Bool

    private(set) var currentFrame: NSImage
    var onStatusItemRefresh: (@MainActor () -> Void)?

    var percentString: String {
        metrics.cpu.percentString(fractionDigits: 0)
    }

    var runnerStateDescription: String {
        metrics.cpu.runnerStateDescription
    }

    private let frames = TortoiseArtwork.makeStatusFrames()
    private let memorySampler = MemorySampler()
    private var frameIndex = 0
    private var frameAccumulator = 0.0
    private var cpuSampler = CPUSampler()
    private var liveCPUDetails = CPUDetails.zero
    private var liveMemoryDetails: MemoryDetails
    private var smoothedCPUUsage = 0.0
    private var lastMetricsPublishDate: Date?
    private var sampleTimer: Timer?
    private var animationTimer: Timer?

    private static let showsPercentageKey = "showsPercentageInMenuBar"
    private static let metricsPublishInterval: TimeInterval = 5

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.showsPercentageKey) == nil {
            defaults.set(true, forKey: Self.showsPercentageKey)
        }

        let zeroMemoryDetails = MemoryDetails.zero(totalBytes: ProcessInfo.processInfo.physicalMemory)
        showsPercentageInMenuBar = defaults.bool(forKey: Self.showsPercentageKey)
        metrics = SystemMetricsSnapshot(cpu: .zero, memory: zeroMemoryDetails)
        liveMemoryDetails = zeroMemoryDetails
        currentFrame = frames[0]
        smoothedCPUUsage = 0
    }

    func start() {
        refresh(forceMetricsPublish: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.refresh(forceMetricsPublish: true)
        }

        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSample(forceMetricsPublish: false)
            }
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickAnimation()
            }
        }
    }

    func stop() {
        sampleTimer?.invalidate()
        animationTimer?.invalidate()
        sampleTimer = nil
        animationTimer = nil
    }

    func refresh() {
        refresh(forceMetricsPublish: true)
    }

    func refresh(forceMetricsPublish: Bool) {
        refreshSample(forceMetricsPublish: forceMetricsPublish)
        refreshLaunchAtLoginState()
    }

    func setShowsPercentageInMenuBar(_ enabled: Bool) {
        showsPercentageInMenuBar = enabled
        UserDefaults.standard.set(enabled, forKey: Self.showsPercentageKey)
        requestStatusItemRefresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        isUpdatingLaunchAtLogin = true

        Task { @MainActor in
            defer {
                isUpdatingLaunchAtLogin = false
                refreshLaunchAtLoginState()
            }

            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                presentLaunchAtLoginError(error)
            }
        }
    }

    private func refreshSample(forceMetricsPublish: Bool) {
        if let sampledDetails = cpuSampler.sample() {
            liveCPUDetails = sampledDetails
        }

        if let sampledMemory = memorySampler.sample() {
            liveMemoryDetails = sampledMemory
        }

        let now = Date()
        if forceMetricsPublish || shouldPublishMetrics(at: now) {
            metrics = SystemMetricsSnapshot(cpu: liveCPUDetails, memory: liveMemoryDetails)
            lastMetricsPublishDate = now
        }

        requestStatusItemRefresh()
    }

    private func refreshLaunchAtLoginState() {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            launchAtLoginEnabled = true
        default:
            launchAtLoginEnabled = false
        }
    }

    private func tickAnimation() {
        smoothedCPUUsage += (liveCPUDetails.totalUsage - smoothedCPUUsage) * 0.22

        guard smoothedCPUUsage >= 0.04 else {
            guard frameIndex != 0 || frameAccumulator != 0 else {
                return
            }

            frameIndex = 0
            frameAccumulator = 0
            currentFrame = frames[0]
            requestStatusItemRefresh()
            return
        }

        frameAccumulator += max(0.18, smoothedCPUUsage * 1.8)
        guard frameAccumulator >= 1 else {
            return
        }

        let stepCount = max(1, Int(frameAccumulator.rounded(.down)))
        frameAccumulator -= Double(stepCount)
        frameIndex = (frameIndex + stepCount) % frames.count
        currentFrame = frames[frameIndex]
        requestStatusItemRefresh()
    }

    private func requestStatusItemRefresh() {
        onStatusItemRefresh?()
    }

    private func shouldPublishMetrics(at date: Date) -> Bool {
        guard let lastMetricsPublishDate else {
            return true
        }

        return date.timeIntervalSince(lastMetricsPublishDate) >= Self.metricsPublishInterval
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.icon = AppIconProvider.appIconImage
        alert.messageText = "Couldn't change launch at login"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

struct SystemMetricsSnapshot {
    let cpu: CPUDetails
    let memory: MemoryDetails

    static func zero(totalBytes: UInt64) -> SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            cpu: .zero,
            memory: .zero(totalBytes: totalBytes)
        )
    }
}

struct CPUDetails {
    let totalUsage: Double
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double

    static let zero = CPUDetails(totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 1)

    var runnerStateDescription: String {
        switch totalUsage {
        case ..<0.05:
            return "Sunbathing"
        case ..<0.2:
            return "Plodding"
        case ..<0.5:
            return "Cruising"
        case ..<0.8:
            return "Hustling"
        default:
            return "Full sprint"
        }
    }

    func percentString(fractionDigits: Int) -> String {
        percentageString(totalUsage, fractionDigits: fractionDigits)
    }
}

struct MemoryDetails {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let activeBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64

    var usedFraction: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    static func zero(totalBytes: UInt64) -> MemoryDetails {
        MemoryDetails(
            totalBytes: totalBytes,
            usedBytes: 0,
            activeBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            cachedBytes: 0
        )
    }
}

private func percentageString(_ value: Double, fractionDigits: Int) -> String {
    String(format: "%.\(fractionDigits)f%%", value * 100)
}

private struct CPUSampler {
    private var previousTicks: [Double]?

    mutating func sample() -> CPUDetails? {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let ticks = [
            Double(loadInfo.cpu_ticks.0),
            Double(loadInfo.cpu_ticks.1),
            Double(loadInfo.cpu_ticks.2),
            Double(loadInfo.cpu_ticks.3),
        ]

        guard let previousTicks else {
            self.previousTicks = ticks
            return nil
        }

        self.previousTicks = ticks

        let deltas = zip(ticks, previousTicks).map { max(0, $0.0 - $0.1) }
        let total = deltas.reduce(0, +)
        guard total > 0 else {
            return .zero
        }

        let user = deltas[Int(CPU_STATE_USER)] + deltas[Int(CPU_STATE_NICE)]
        let system = deltas[Int(CPU_STATE_SYSTEM)]
        let idle = deltas[Int(CPU_STATE_IDLE)]
        let busy = user + system

        return CPUDetails(
            totalUsage: min(max(busy / total, 0), 1),
            userUsage: min(max(user / total, 0), 1),
            systemUsage: min(max(system / total, 0), 1),
            idleUsage: min(max(idle / total, 0), 1)
        )
    }
}

private struct MemorySampler {
    func sample() -> MemoryDetails? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return nil
        }

        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let bytesPerPage = UInt64(pageSize)

        let activeBytes = UInt64(statistics.active_count) * bytesPerPage
        let inactiveBytes = UInt64(statistics.inactive_count) * bytesPerPage
        let wiredBytes = UInt64(statistics.wire_count) * bytesPerPage
        let compressedBytes = UInt64(statistics.compressor_page_count) * bytesPerPage
        let speculativeBytes = UInt64(statistics.speculative_count) * bytesPerPage
        let purgeableBytes = UInt64(statistics.purgeable_count) * bytesPerPage

        let cachedBytes = inactiveBytes + speculativeBytes + purgeableBytes
        let usedBytes = min(totalBytes, activeBytes + wiredBytes + compressedBytes)

        return MemoryDetails(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            activeBytes: activeBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            cachedBytes: cachedBytes
        )
    }
}

enum TortoiseArtwork {
    static func makeStatusFrames() -> [NSImage] {
        let frameCount = 18

        return (0..<frameCount).map { phase in
            let image = NSImage(size: NSSize(width: 26, height: 18))
            image.lockFocus()
            drawStatusFrame(progress: Double(phase) / Double(frameCount))
            image.unlockFocus()
            image.isTemplate = true
            return image
        }
    }

    static func drawIcon(in rect: NSRect) {
        let shell = NSBezierPath(roundedRect: NSRect(x: rect.minX + 24, y: rect.minY + 42, width: 92, height: 56), xRadius: 26, yRadius: 26)
        NSColor(calibratedRed: 0.29, green: 0.43, blue: 0.24, alpha: 1).setFill()
        shell.fill()

        let shellPattern = NSBezierPath()
        shellPattern.lineWidth = 10
        shellPattern.lineCapStyle = .round
        NSColor(calibratedRed: 0.84, green: 0.9, blue: 0.75, alpha: 0.65).setStroke()
        shellPattern.move(to: CGPoint(x: rect.minX + 48, y: rect.minY + 66))
        shellPattern.line(to: CGPoint(x: rect.minX + 92, y: rect.minY + 66))
        shellPattern.move(to: CGPoint(x: rect.minX + 69, y: rect.minY + 50))
        shellPattern.line(to: CGPoint(x: rect.minX + 69, y: rect.minY + 84))
        shellPattern.stroke()

        let head = NSBezierPath(ovalIn: NSRect(x: rect.minX + 118, y: rect.minY + 56, width: 30, height: 24))
        NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.31, alpha: 1).setFill()
        head.fill()

        let eye = NSBezierPath(ovalIn: NSRect(x: rect.minX + 132, y: rect.minY + 68, width: 4, height: 4))
        NSColor.white.setFill()
        eye.fill()

        let pupil = NSBezierPath(ovalIn: NSRect(x: rect.minX + 133, y: rect.minY + 68.5, width: 2, height: 2))
        NSColor.black.setFill()
        pupil.fill()

        let tail = NSBezierPath()
        tail.move(to: CGPoint(x: rect.minX + 22, y: rect.minY + 66))
        tail.line(to: CGPoint(x: rect.minX + 8, y: rect.minY + 74))
        tail.line(to: CGPoint(x: rect.minX + 18, y: rect.minY + 60))
        tail.close()
        NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.31, alpha: 1).setFill()
        tail.fill()

        let legPath = NSBezierPath()
        legPath.lineWidth = 12
        legPath.lineCapStyle = .round
        NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.31, alpha: 1).setStroke()
        legPath.move(to: CGPoint(x: rect.minX + 44, y: rect.minY + 40))
        legPath.line(to: CGPoint(x: rect.minX + 34, y: rect.minY + 18))
        legPath.move(to: CGPoint(x: rect.minX + 76, y: rect.minY + 40))
        legPath.line(to: CGPoint(x: rect.minX + 90, y: rect.minY + 18))
        legPath.move(to: CGPoint(x: rect.minX + 106, y: rect.minY + 42))
        legPath.line(to: CGPoint(x: rect.minX + 118, y: rect.minY + 20))
        legPath.move(to: CGPoint(x: rect.minX + 130, y: rect.minY + 44))
        legPath.line(to: CGPoint(x: rect.minX + 142, y: rect.minY + 24))
        legPath.stroke()
    }

    private static func drawStatusFrame(progress: Double) {
        let bob = CGFloat(sin(progress * .pi * 2)) * 0.22

        let shellRect = NSRect(x: 6, y: 6 + bob, width: 11, height: 7)
        let shell = NSBezierPath(roundedRect: shellRect, xRadius: 4, yRadius: 4)
        NSColor.black.setFill()
        shell.fill()

        let shellPattern = NSBezierPath()
        shellPattern.lineWidth = 1
        shellPattern.lineCapStyle = .round
        shellPattern.move(to: CGPoint(x: 9, y: 9.5 + bob))
        shellPattern.line(to: CGPoint(x: 14, y: 9.5 + bob))
        shellPattern.move(to: CGPoint(x: 11.5, y: 8 + bob))
        shellPattern.line(to: CGPoint(x: 11.5, y: 11 + bob))
        shellPattern.stroke()

        let head = NSBezierPath(ovalIn: NSRect(x: 17.05, y: 8 + bob * 0.85, width: 4.4, height: 3.4))
        head.fill()

        let tail = NSBezierPath()
        tail.move(to: CGPoint(x: 5.4, y: 9.1 + bob))
        tail.line(to: CGPoint(x: 3.8, y: 10.2 + bob * 0.9))
        tail.line(to: CGPoint(x: 4.8, y: 8.2 + bob * 0.9))
        tail.close()
        tail.fill()

        drawLegs(progress: progress, bob: bob)
        drawDust(progress: progress)
    }

    private static func drawLegs(progress: Double, bob: CGFloat) {
        let variants: [[(CGPoint, CGPoint)]] = [
            [
                (CGPoint(x: 8, y: 6.4), CGPoint(x: 6.8, y: 4.6)),
                (CGPoint(x: 11, y: 6.2), CGPoint(x: 11.8, y: 4.3)),
                (CGPoint(x: 14.4, y: 6.2), CGPoint(x: 13.6, y: 4.2)),
                (CGPoint(x: 17.3, y: 6.4), CGPoint(x: 18.6, y: 4.8)),
            ],
            [
                (CGPoint(x: 8, y: 6.3), CGPoint(x: 7.5, y: 4.5)),
                (CGPoint(x: 11, y: 6.2), CGPoint(x: 12.2, y: 4.7)),
                (CGPoint(x: 14.4, y: 6.2), CGPoint(x: 13.2, y: 4.5)),
                (CGPoint(x: 17.3, y: 6.4), CGPoint(x: 17.8, y: 4.6)),
            ],
            [
                (CGPoint(x: 8, y: 6.2), CGPoint(x: 8.7, y: 4.2)),
                (CGPoint(x: 11, y: 6.2), CGPoint(x: 10.1, y: 4.4)),
                (CGPoint(x: 14.4, y: 6.2), CGPoint(x: 15.4, y: 4.5)),
                (CGPoint(x: 17.3, y: 6.3), CGPoint(x: 16.4, y: 4.4)),
            ],
            [
                (CGPoint(x: 8, y: 6.4), CGPoint(x: 6.7, y: 4.8)),
                (CGPoint(x: 11, y: 6.2), CGPoint(x: 11.9, y: 4.3)),
                (CGPoint(x: 14.4, y: 6.1), CGPoint(x: 13.7, y: 4.3)),
                (CGPoint(x: 17.3, y: 6.3), CGPoint(x: 18.4, y: 4.4)),
            ],
            [
                (CGPoint(x: 8, y: 6.1), CGPoint(x: 7.4, y: 4.3)),
                (CGPoint(x: 11, y: 6.1), CGPoint(x: 12.1, y: 4.7)),
                (CGPoint(x: 14.4, y: 6.2), CGPoint(x: 13.3, y: 4.6)),
                (CGPoint(x: 17.3, y: 6.2), CGPoint(x: 17.8, y: 4.2)),
            ],
            [
                (CGPoint(x: 8, y: 6.2), CGPoint(x: 8.8, y: 4.5)),
                (CGPoint(x: 11, y: 6.3), CGPoint(x: 10.2, y: 4.3)),
                (CGPoint(x: 14.4, y: 6.3), CGPoint(x: 15.2, y: 4.2)),
                (CGPoint(x: 17.3, y: 6.2), CGPoint(x: 16.5, y: 4.7)),
            ],
        ]

        let position = progress * Double(variants.count)
        let lowerIndex = Int(position.rounded(.down)) % variants.count
        let upperIndex = (lowerIndex + 1) % variants.count
        let interpolation = CGFloat(position - Double(lowerIndex))

        let path = NSBezierPath()
        path.lineWidth = 1.35
        path.lineCapStyle = .round

        for legIndex in variants[lowerIndex].indices {
            let lower = variants[lowerIndex][legIndex]
            let upper = variants[upperIndex][legIndex]
            let start = interpolate(from: lower.0, to: upper.0, amount: interpolation, yOffset: bob)
            let end = interpolate(from: lower.1, to: upper.1, amount: interpolation, yOffset: 0)

            path.move(to: start)
            path.line(to: end)
        }
        path.stroke()
    }

    private static func drawDust(progress: Double) {
        let offsets: [CGFloat] = [0, 0.4, 0.8, 0.2, 0.6, 1.0]
        let position = progress * Double(offsets.count)
        let lowerIndex = Int(position.rounded(.down)) % offsets.count
        let upperIndex = (lowerIndex + 1) % offsets.count
        let interpolation = CGFloat(position - Double(lowerIndex))
        let shift = offsets[lowerIndex] + (offsets[upperIndex] - offsets[lowerIndex]) * interpolation

        let dust = NSBezierPath()
        dust.lineWidth = 0.9
        dust.lineCapStyle = .round
        dust.move(to: CGPoint(x: 1.2 + shift, y: 6.4))
        dust.line(to: CGPoint(x: 2.8 + shift, y: 6.4))
        dust.move(to: CGPoint(x: 0.4 + shift, y: 8.1))
        dust.line(to: CGPoint(x: 1.6 + shift, y: 8.1))
        dust.stroke()
    }

    private static func interpolate(from start: CGPoint, to end: CGPoint, amount: CGFloat, yOffset: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * amount,
            y: start.y + (end.y - start.y) * amount + yOffset
        )
    }
}
