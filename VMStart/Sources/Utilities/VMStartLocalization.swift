//
//  VMStartLocalization.swift
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

import Foundation

// MARK: - Localization Helper (replaces VMStartLocalization.h macros)

enum AML {
    /// Simple localized string lookup
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    /// Formatted localized string
    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: args)
    }
}

// MARK: - Common UI Strings

extension AML {
    static var appName: String { string("app_name") }
    static var appSubtitle: String { string("app_subtitle") }
    static var welcome: String { string("welcome_title") }
    static var welcomeSubtitle: String { string("welcome_subtitle") }
    static var createNewVM: String { string("create_new_vm") }
    static var openExistingVM: String { string("open_existing_vm") }
    static var deleteVMConfirm: String { string("delete_vm_confirm") }
    static var myVirtualMachines: String { string("my_virtual_machines") }

    // Modes
    static var modeSimple: String { string("mode_simple") }
    static var modeStandard: String { string("mode_standard") }
    static var modeAdvanced: String { string("mode_advanced") }

    // Console
    static var consoleStart: String { string("console_start") }
    static var consoleStop: String { string("console_stop") }
    static var consolePause: String { string("console_pause") }
    static var consoleResume: String { string("console_resume") }
    static var consoleMedia: String { string("console_media") }
    static var consoleCapture: String { string("console_capture") }
    static var consoleFullscreen: String { string("console_fullscreen") }

    // Config Wizard Steps
    static var stepBasic: String { string("step_basic") }
    static var stepHardware: String { string("step_hardware") }
    static var stepStorage: String { string("step_storage") }
    static var stepNetwork: String { string("step_network") }
    static var stepDisplay: String { string("step_display") }
    static var stepSummary: String { string("step_summary") }

    // Network Modes
    static var networkNAT: String { string("network_nat") }
    static var networkBridge: String { string("network_bridge") }
    static var networkHostOnly: String { string("network_hostonly") }
    static var networkModem: String { string("network_modem") }
    static var networkTerminal: String { string("network_terminal") }
    static var networkNone: String { string("network_none") }
}
