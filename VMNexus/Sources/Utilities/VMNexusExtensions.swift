//
//  VMNexusExtensions.swift
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

import Foundation
import Cocoa

// MARK: - VM Statistics
@objc class VMNexusStatistics: NSObject {
    @objc static let shared = VMNexusStatistics()
    
    @objc var totalVMsCreated: Int {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        let vmDir = appSupport.appendingPathComponent("VMNexus/VirtualMachines")
        let contents = try? fm.contentsOfDirectory(at: vmDir, includingPropertiesForKeys: nil)
        return contents?.filter { $0.pathExtension == "vmnexus" }.count ?? 0
    }
    
    @objc var totalDiskUsage: String {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return "0 MB" }
        let vmDir = appSupport.appendingPathComponent("VMNexus/VirtualMachines")
        guard let contents = try? fm.contentsOfDirectory(at: vmDir, includingPropertiesForKeys: nil) else { return "0 MB" }
        var totalSize: UInt64 = 0
        for url in contents where url.pathExtension == "vmnexus" {
            totalSize += directorySize(url)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    private func directorySize(_ url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var totalSize: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += UInt64(resourceValues?.fileSize ?? 0)
        }
        return totalSize
    }
}

// MARK: - NSColor Extensions
extension NSColor {
    static let vmnexusAccent = NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
    static let vmnexusSuccess = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
    static let vmnexusWarning = NSColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1.0)
    static let vmnexusError = NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
    static let vmnexusConsoleBg = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
}

// MARK: - Date Formatting
extension Date {
    var vmnexusRelativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var vmnexusFullString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - String Extensions
extension String {
    var isValidVMName: Bool {
        let pattern = "^[a-zA-Z0-9\\s\\-_\\.]{1,64}$"
        return range(of: pattern, options: .regularExpression) != nil
    }
}
