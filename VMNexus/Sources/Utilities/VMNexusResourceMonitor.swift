//
//  VMNexusResourceMonitor.swift
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

import Cocoa

/// Real-time resource monitor for running VMs
/// Shows CPU usage, memory usage, disk I/O, and network I/O
@objc public class VMNexusResourceMonitor: NSView {

    private var timer: Timer?
    private var pid: pid_t = 0

    // UI elements
    private var cpuBar: NSLevelIndicator!
    private var cpuLabel: NSTextField!
    private var memBar: NSLevelIndicator!
    private var memLabel: NSTextField!
    private var diskReadLabel: NSTextField!
    private var diskWriteLabel: NSTextField!
    private var netInLabel: NSTextField!
    private var netOutLabel: NSTextField!
    private var uptimeLabel: NSTextField!

    // Previous values for delta calculation
    private var prevCPUTime: UInt64 = 0
    private var prevDiskRead: UInt64 = 0
    private var prevDiskWrite: UInt64 = 0
    private var prevNetIn: UInt64 = 0
    private var prevNetOut: UInt64 = 0
    private var startTime: Date = Date()

    @objc public override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor

        let title = makeSectionTitle("RESOURCE MONITOR", y: bounds.height - 30)
        addSubview(title)

        var y: CGFloat = bounds.height - 64

        // CPU Usage
        y = addMeterRow(label: "CPU", y: &y) { bar, label in
            self.cpuBar = bar; self.cpuLabel = label
        }

        // Memory Usage
        y = addMeterRow(label: "Memory", y: &y) { bar, label in
            self.memBar = bar; self.memLabel = label
        }

        // Disk I/O
        y -= 8
        let diskTitle = makeSectionTitle("DISK I/O", y: y)
        addSubview(diskTitle)
        y -= 28

        diskReadLabel = makeValueLabel("Read: -- MB/s", y: y)
        addSubview(diskReadLabel)
        y -= 22

        diskWriteLabel = makeValueLabel("Write: -- MB/s", y: y)
        addSubview(diskWriteLabel)
        y -= 28

        // Network I/O
        let netTitle = makeSectionTitle("NETWORK I/O", y: y)
        addSubview(netTitle)
        y -= 28

        netInLabel = makeValueLabel("↓ In: -- KB/s", y: y)
        addSubview(netInLabel)
        y -= 22

        netOutLabel = makeValueLabel("↑ Out: -- KB/s", y: y)
        addSubview(netOutLabel)
        y -= 28

        // Uptime
        uptimeLabel = makeValueLabel("Uptime: --", y: y)
        addSubview(uptimeLabel)
    }

    private func addMeterRow(label: String, y: inout CGFloat, setup: (NSLevelIndicator, NSTextField) -> Void) -> CGFloat {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = NSColor.secondaryLabelColor
        lbl.frame = NSRect(x: 16, y: y, width: 60, height: 16)
        lbl.isBezeled = false
        lbl.drawsBackground = false
        addSubview(lbl)

        let bar = NSLevelIndicator(frame: NSRect(x: 80, y: y + 2, width: 200, height: 14))
        bar.levelIndicatorStyle = .continuousCapacity
        bar.minValue = 0
        bar.maxValue = 100
        bar.warningValue = 70
        bar.criticalValue = 90
        addSubview(bar)

        let valLabel = NSTextField(labelWithString: "0%")
        valLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valLabel.textColor = NSColor.labelColor
        valLabel.frame = NSRect(x: 290, y: y, width: 60, height: 16)
        valLabel.isBezeled = false
        valLabel.drawsBackground = false
        addSubview(valLabel)

        setup(bar, valLabel)
        y -= 32
        return y
    }

    private func makeSectionTitle(_ text: String, y: CGFloat) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        lbl.textColor = NSColor.tertiaryLabelColor
        lbl.frame = NSRect(x: 16, y: y, width: 200, height: 14)
        lbl.isBezeled = false
        lbl.drawsBackground = false
        return lbl
    }

    private func makeValueLabel(_ text: String, y: CGFloat) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        lbl.textColor = NSColor.labelColor
        lbl.frame = NSRect(x: 24, y: y, width: 280, height: 16)
        lbl.isBezeled = false
        lbl.drawsBackground = false
        return lbl
    }

    // ─── Public API ───

    @objc public func startMonitoring(processID: Int32) {
        pid = processID
        startTime = Date()
        prevCPUTime = 0
        prevDiskRead = 0
        prevDiskWrite = 0
        prevNetIn = 0
        prevNetOut = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    @objc public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        pid = 0
    }

    // ─── Stats Collection ───

    private func updateStats() {
        guard pid > 0 else { return }

        // CPU usage
        let cpuPercent = getCPUUsage(pid: pid)
        cpuBar.doubleValue = min(cpuPercent, 100)
        cpuLabel.stringValue = String(format: "%.0f%%", cpuPercent)

        // Memory usage
        let (memUsedMB, memPercent) = getMemoryUsage(pid: pid)
        memBar.doubleValue = min(memPercent, 100)
        memLabel.stringValue = String(format: "%.0f MB (%.0f%%)", memUsedMB, memPercent)

        // Disk I/O (from /proc-like info or rusage)
        let (diskR, diskW) = getDiskIO(pid: pid)
        let readDelta = diskR > prevDiskRead ? Double(diskR - prevDiskRead) / (1024 * 1024) : 0
        let writeDelta = diskW > prevDiskWrite ? Double(diskW - prevDiskWrite) / (1024 * 1024) : 0
        prevDiskRead = diskR
        prevDiskWrite = diskW
        diskReadLabel.stringValue = String(format: "Read: %.2f MB/s", readDelta)
        diskWriteLabel.stringValue = String(format: "Write: %.2f MB/s", writeDelta)

        // Network I/O
        let (netIn, netOut) = getNetworkIO(pid: pid)
        let inDelta = netIn > prevNetIn ? Double(netIn - prevNetIn) / 1024 : 0
        let outDelta = netOut > prevNetOut ? Double(netOut - prevNetOut) / 1024 : 0
        prevNetIn = netIn
        prevNetOut = netOut
        netInLabel.stringValue = String(format: "↓ In: %.1f KB/s", inDelta)
        netOutLabel.stringValue = String(format: "↑ Out: %.1f KB/s", outDelta)

        // Uptime
        let uptime = Date().timeIntervalSince(startTime)
        let hours = Int(uptime) / 3600
        let mins = (Int(uptime) % 3600) / 60
        let secs = Int(uptime) % 60
        uptimeLabel.stringValue = String(format: "Uptime: %02d:%02d:%02d", hours, mins, secs)
    }

    private func getCPUUsage(pid: pid_t) -> Double {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var size = MemoryLayout<kinfo_proc>.stride
        if sysctl(&mib, 4, &info, &size, nil, 0) != 0 { return 0 }

        var rusage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &rusage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { ptr -> Int32 in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, ptr)
            }
        }
        if result != 0 { return 0 }

        let totalTime = rusage.ri_user_time + rusage.ri_system_time
        let delta = totalTime > prevCPUTime ? totalTime - prevCPUTime : 0
        prevCPUTime = totalTime

        // Convert from Mach time units to seconds, then to percent
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let deltaNs = Double(delta) * Double(timebase.numer) / Double(timebase.denom)
        let cpuSeconds = deltaNs / 1_000_000_000.0
        // Percentage of one core
        return min(cpuSeconds * 100.0, 100.0 * Double(ProcessInfo.processInfo.activeProcessorCount))
    }

    private func getMemoryUsage(pid: pid_t) -> (Double, Double) {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let ret = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: UInt8.self, capacity: size) { ptr in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, Int32(size))
            }
        }
        if ret <= 0 { return (0, 0) }

        let memBytes = Double(info.pti_resident_size)
        let memMB = memBytes / (1024 * 1024)

        // Get total system memory
        let totalMem = ProcessInfo.processInfo.physicalMemory
        let percent = (memBytes / Double(totalMem)) * 100.0

        return (memMB, percent)
    }

    private func getDiskIO(pid: pid_t) -> (UInt64, UInt64) {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { ptr -> Int32 in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, ptr)
            }
        }
        if result != 0 { return (0, 0) }
        return (info.ri_diskio_bytesread, info.ri_diskio_byteswritten)
    }

    private func getNetworkIO(pid: pid_t) -> (UInt64, UInt64) {
        // macOS doesn't provide per-process network stats easily
        // We use rusage for a rough estimate or /proc/net equivalent
        var rusage = rusage()
        if getrusage(RUSAGE_SELF, &rusage) != 0 { return (0, 0) }
        // Use ru_inblock and ru_oublock as rough proxy (these are actually disk blocks)
        // For better accuracy we'd need Network.framework or nettop
        return (UInt64(rusage.ru_inblock) * 512, UInt64(rusage.ru_oublock) * 512)
    }

    deinit {
        stopMonitoring()
    }
}
