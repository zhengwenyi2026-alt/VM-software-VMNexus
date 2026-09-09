//
//  VMNexusVNCViewer.swift
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//
//  Full VNC (RFB 3.8) client — connects to QEMU's VNC server and renders
//  the VM framebuffer inside an NSView.  Supports Raw + DesktopSize
//  encodings, full keyboard (X11 keysym) and mouse (3 buttons + scroll).
//

import Cocoa

// MARK: - VNC Error

enum VNCError: Error, CustomStringConvertible {
    case socketFailed, connectionFailed, invalidProtocol
    case noSecurityTypes, unsupportedSecurity, securityFailed(UInt32)
    case readFailed, writeFailed, encodingNotSupported(Int32)
    var description: String {
        switch self {
        case .socketFailed: return "Cannot create socket streams"
        case .connectionFailed: return "Connection timed out"
        case .invalidProtocol: return "Invalid RFB protocol"
        case .noSecurityTypes: return "Server offers no security types"
        case .unsupportedSecurity: return "No supported security type"
        case .securityFailed(let c): return "Security handshake failed (\(c))"
        case .readFailed: return "Read from server failed"
        case .writeFailed: return "Write to server failed"
        case .encodingNotSupported(let e): return "Encoding \(e) not supported"
        }
    }
}

// MARK: - X11 Keysym mapping

enum VNCKey {
    static func fromKeyCode(_ kc: UInt16, char: String?, modifiers: NSEvent.ModifierFlags) -> UInt32 {
        // Special keys
        switch kc {
        case 0x24: return 0xFF0D // Return
        case 0x30: return 0xFF09 // Tab
        case 0x33: return 0xFF08 // BackSpace
        case 0x35: return 0xFF1B // Escape
        case 0x75: return 0xFFFF // Delete (forward)
        case 0x73: return 0xFF50 // Home
        case 0x77: return 0xFF57 // End
        case 0x74: return 0xFF55 // PageUp
        case 0x79: return 0xFF56 // PageDown
        case 0x7B: return 0xFF51 // Left
        case 0x7E: return 0xFF52 // Up
        case 0x7C: return 0xFF53 // Right
        case 0x7D: return 0xFF54 // Down
        case 0x72: return 0xFF63 // Insert/Help
        case 0x7A: return 0xFFBE // F1
        case 0x78: return 0xFFBF // F2
        case 0x63: return 0xFFC0 // F3
        case 0x76: return 0xFFC1 // F4
        case 0x60: return 0xFFC2 // F5
        case 0x61: return 0xFFC3 // F6
        case 0x62: return 0xFFC4 // F7
        case 0x64: return 0xFFC5 // F8
        case 0x65: return 0xFFC6 // F9
        case 0x6D: return 0xFFC7 // F10
        case 0x67: return 0xFFC8 // F11
        case 0x6F: return 0xFFC9 // F12
        default: break
        }
        // Modifier keys
        if modifiers.contains(.shift) && kc == 0x38 { return 0xFFE1 }
        if kc == 0x3B && modifiers.contains(.control) { return 0xFFE3 }
        if kc == 0x3A && modifiers.contains(.option) { return 0xFFE9 }
        // Character fallback via Unicode scalar
        if let ch = char, let scalar = ch.unicodeScalars.first {
            let v = scalar.value
            if v >= 0x61 && v <= 0x7A { return v - 0x20 }  // lowercase → upper
            if v <= 0xFF { return v }
            return 0x01000000 | v  // Unicode
        }
        return 0
    }
}

// MARK: - Mouse button masks

enum VNCButton {
    static let left: UInt8   = 1
    static let middle: UInt8 = 2
    static let right: UInt8  = 4
    static let wheelUp: UInt8   = 8
    static let wheelDown: UInt8 = 16
}

// MARK: - VMNexusVNCViewer

@objc public class VMNexusVNCViewer: NSView {

    @objc public var isConnected = false
    @objc public var framebufferWidth: Int = 0
    @objc public var framebufferHeight: Int = 0
    @objc public var onConnected: (() -> Void)?
    @objc public var onDisconnected: (() -> Void)?

    private var host = "127.0.0.1"
    private var port = 5900
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var worker: Thread?
    private var running = false

    // Framebuffer
    private var fb: [UInt8] = []
    private var bytesPerPixel = 4
    private var bigEndian = false
    private var rShift: UInt32 = 16, gShift: UInt32 = 8, bShift: UInt32 = 0
    private var rMax: UInt32 = 255, gMax: UInt32 = 255, bMax: UInt32 = 255
    private var displayImage: NSImage?
    private let imgLock = NSLock()
    private var mouseMask: UInt8 = 0

    // ─── Init ───

    public override init(frame f: NSRect) { super.init(frame: f); common() }
    required init?(coder c: NSCoder) { super.init(coder: c); common() }
    private func common() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    override public var acceptsFirstResponder: Bool { true }
    override public var isFlipped: Bool { true }  // VNC y=0 is top

    // ─── Connect / Disconnect ───

    @objc public func connect(host h: String = "127.0.0.1", port p: Int = 5900) {
        disconnect()
        host = h; port = p; running = true
        worker = Thread(target: self, selector: #selector(run), object: nil)
        worker?.name = "VNC"; worker?.qualityOfService = .userInteractive
        worker?.start()
    }

    @objc public func disconnect() {
        running = false; isConnected = false
        inputStream?.close(); outputStream?.close()
        inputStream = nil; outputStream = nil
        worker?.cancel(); worker = nil
        DispatchQueue.main.async { [weak self] in self?.onDisconnected?() }
    }

    deinit { disconnect() }

    // ─── Background run loop ───

    @objc private func run() {
        autoreleasepool {
            do {
                try openSocket()
                try handshake()
                try serverInit()
                isConnected = true
                DispatchQueue.main.async { [weak self] in self?.onConnected?() }
                try fbUpdateRequest(incremental: false)
                try eventLoop()
            } catch {
                vlog("VNC error: \(error)")
            }
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.onDisconnected?()
            }
        }
    }

    // ─── Socket ───

    private func openSocket() throws {
        var rs: Unmanaged<CFReadStream>?, ws: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, UInt32(port), &rs, &ws)
        guard let inp = rs?.takeRetainedValue() as InputStream?,
              let out = ws?.takeRetainedValue() as OutputStream? else { throw VNCError.socketFailed }
        inputStream = inp; outputStream = out
        inp.open(); out.open()
        for _ in 0..<50 {
            if inp.streamStatus == .open && inp.hasBytesAvailable { break }
            if inp.streamStatus == .error || inp.streamStatus == .closed { throw VNCError.connectionFailed }
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard inp.streamStatus == .open else { throw VNCError.connectionFailed }
    }

    // ─── RFB Handshake ───

    private func handshake() throws {
        let ver = try readBytes(12)
        guard String(bytes: ver, encoding: .ascii)?.hasPrefix("RFB ") == true
            else { throw VNCError.invalidProtocol }
        try writeBytes(Array("RFB 003.008\n".utf8))
        let n = try readU8()
        guard n > 0 else { throw VNCError.noSecurityTypes }
        let types = try readBytes(Int(n))
        guard types.contains(1) else { throw VNCError.unsupportedSecurity }
        try writeBytes([1])  // None
        let result = try readU32()
        guard result == 0 else { throw VNCError.securityFailed(result) }
    }

    // ─── ServerInit ───

    private func serverInit() throws {
        let w = try readU16(), h = try readU16()
        framebufferWidth = Int(w); framebufferHeight = Int(h)
        let pf = try readBytes(16)
        let bPP = Int(pf[0]) / 8
        bytesPerPixel = bPP
        bigEndian = pf[2] != 0
        rMax = u16(pf[4], pf[5]); gMax = u16(pf[6], pf[7]); bMax = u16(pf[8], pf[9])
        rShift = UInt32(pf[10]); gShift = UInt32(pf[11]); bShift = UInt32(pf[12])
        let nameLen = try readU32()
        if nameLen > 0 { let _ = try readBytes(Int(nameLen)) }
        fb = [UInt8](repeating: 0, count: framebufferWidth * framebufferHeight * bytesPerPixel)
        vlog("VNC: \(framebufferWidth)x\(framebufferHeight) \(bPP*8)bpp")
    }

    // ─── Event Loop ───

    private func eventLoop() throws {
        while running && !Thread.current.isCancelled {
            guard let inp = inputStream else { break }
            if !inp.hasBytesAvailable {
                Thread.sleep(forTimeInterval: 0.005); continue
            }
            let msg = try readU8()
            switch msg {
            case 0: try handleFBUpdate(); try fbUpdateRequest(incremental: true)
            case 1: break // SetColourMapEntries (ignored, true-colour)
            case 2: NSSound.beep()  // Bell
            case 3: try handleServerCutText()
            default: break
            }
        }
    }

    // ─── FramebufferUpdate ───

    private func fbUpdateRequest(incremental inc: Bool) throws {
        var m: [UInt8] = [3, inc ? 1 : 0]
        m += be16(0); m += be16(0)
        m += be16(UInt16(framebufferWidth)); m += be16(UInt16(framebufferHeight))
        try writeBytes(m)
    }

    private func handleFBUpdate() throws {
        let _ = try readU8()  // padding
        let numRects = try readU16()
        for _ in 0..<numRects {
            let x = Int(try readU16()), y = Int(try readU16())
            let w = Int(try readU16()), h = Int(try readU16())
            let enc = try readI32()
            switch enc {
            case 0: try decodeRaw(x: x, y: y, w: w, h: h)
            case -223:  // DesktopSize
                framebufferWidth = w; framebufferHeight = h
                fb = [UInt8](repeating: 0, count: w * h * bytesPerPixel)
                DispatchQueue.main.async { [weak self] in self?.needsDisplay = true }
            default:
                vlog("VNC: skipping encoding \(enc)")
            }
        }
        // Render to NSImage on main thread
        imgLock.lock()
        displayImage = buildImage()
        imgLock.unlock()
        DispatchQueue.main.async { [weak self] in self?.needsDisplay = true }
    }

    private func decodeRaw(x: Int, y: Int, w: Int, h: Int) throws {
        let rowBytes = w * bytesPerPixel
        for row in 0..<h {
            let data = try readBytes(rowBytes)
            let dstY = y + row
            guard dstY < framebufferHeight else { continue }
            let dstOff = dstY * framebufferWidth * bytesPerPixel + x * bytesPerPixel
            let srcEnd = min(data.count, (framebufferWidth - x) * bytesPerPixel)
            for i in 0..<srcEnd where dstOff + i < fb.count {
                fb[dstOff + i] = data[i]
            }
        }
    }

    private func handleServerCutText() throws {
        let _ = try readBytes(3) // padding
        let len = try readU32()
        let text = try readBytes(Int(len))
        if let s = String(bytes: text, encoding: .utf8) {
            DispatchQueue.main.async {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(s, forType: .string)
            }
        }
    }

    // ─── Rendering ───

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.setFill()
        dirtyRect.fill()
        imgLock.lock()
        let img = displayImage
        imgLock.unlock()
        guard let image = img else { return }
        // Scale to fit
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let w = image.size.width * scale, h = image.size.height * scale
        let ox = (bounds.width - w) / 2, oy = (bounds.height - h) / 2
        image.draw(in: NSRect(x: ox, y: oy, width: w, height: h))
    }

    private func buildImage() -> NSImage? {
        let w = framebufferWidth, h = framebufferHeight
        guard w > 0, h > 0 else { return nil }
        // Convert VNC pixel data → RGBA bitmap
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) {
            let sOff = i * bytesPerPixel
            guard sOff + bytesPerPixel <= fb.count else { break }
            var pixel: UInt32 = 0
            if bigEndian {
                for b in 0..<bytesPerPixel { pixel = (pixel << 8) | UInt32(fb[sOff + b]) }
            } else {
                for b in 0..<bytesPerPixel { pixel |= UInt32(fb[sOff + b]) << (b * 8) }
            }
            let r = ((pixel >> rShift) & rMax) * 255 / max(rMax, 1)
            let g = ((pixel >> gShift) & gMax) * 255 / max(gMax, 1)
            let b = ((pixel >> bShift) & bMax) * 255 / max(bMax, 1)
            let dOff = i * 4
            rgba[dOff] = UInt8(r); rgba[dOff+1] = UInt8(g); rgba[dOff+2] = UInt8(b); rgba[dOff+3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else { return nil }
        return NSImage(cgImage: cgImg, size: NSSize(width: w, height: h))
    }

    // ─── Keyboard ───

    override public func keyDown(with event: NSEvent) {
        guard isConnected else { super.keyDown(with: event); return }
        let ks = VNCKey.fromKeyCode(event.keyCode, char: event.characters, modifiers: event.modifierFlags)
        sendKeyEvent(keysym: ks, down: true)
    }
    override public func keyUp(with event: NSEvent) {
        guard isConnected else { return }
        let ks = VNCKey.fromKeyCode(event.keyCode, char: event.characters, modifiers: event.modifierFlags)
        sendKeyEvent(keysym: ks, down: false)
    }
    override public func flagsChanged(with event: NSEvent) {
        guard isConnected else { return }
        let f = event.modifierFlags
        sendKeyEvent(keysym: 0xFFE1, down: f.contains(.shift))   // Shift
        sendKeyEvent(keysym: 0xFFE3, down: f.contains(.control)) // Control
        sendKeyEvent(keysym: 0xFFE9, down: f.contains(.option))  // Alt
        sendKeyEvent(keysym: 0xFFE7, down: f.contains(.command)) // Meta/Super
    }

    private func sendKeyEvent(keysym: UInt32, down: Bool) {
        var m: [UInt8] = [4, down ? 1 : 0, 0, 0]
        m += be32(keysym)
        try? writeBytes(m)
    }

    // ─── Mouse ───

    override public func mouseDown(with e: NSEvent) {
        mouseMask |= VNCButton.left; sendPointer(e)
    }
    override public func mouseUp(with e: NSEvent) {
        mouseMask &= ~VNCButton.left; sendPointer(e)
    }
    override public func rightMouseDown(with e: NSEvent) {
        mouseMask |= VNCButton.right; sendPointer(e)
    }
    override public func rightMouseUp(with e: NSEvent) {
        mouseMask &= ~VNCButton.right; sendPointer(e)
    }
    override public func otherMouseDown(with e: NSEvent) {
        mouseMask |= VNCButton.middle; sendPointer(e)
    }
    override public func otherMouseUp(with e: NSEvent) {
        mouseMask &= ~VNCButton.middle; sendPointer(e)
    }
    override public func mouseMoved(with e: NSEvent) { sendPointer(e) }
    override public func mouseDragged(with e: NSEvent) { sendPointer(e) }
    override public func scrollWheel(with e: NSEvent) {
        let up = e.scrollingDeltaY > 0
        mouseMask |= up ? VNCButton.wheelUp : VNCButton.wheelDown
        sendPointer(e)
        mouseMask &= ~(VNCButton.wheelUp | VNCButton.wheelDown)
        sendPointer(e)
    }

    override public func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    private func sendPointer(_ e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        guard let img = displayImage else { return }
        let scale = min(bounds.width / img.size.width, bounds.height / img.size.height)
        let ox = (bounds.width - img.size.width * scale) / 2
        let oy = (bounds.height - img.size.height * scale) / 2
        let vx = Int((p.x - ox) / scale)
        let vy = Int((p.y - oy) / scale)
        let cx = max(0, min(framebufferWidth - 1, vx))
        let cy = max(0, min(framebufferHeight - 1, vy))
        var m: [UInt8] = [5, mouseMask]
        m += be16(UInt16(cx)); m += be16(UInt16(cy))
        try? writeBytes(m)
    }

    // ─── Tracking area ───

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self))
    }

    // ─── Wire helpers ───

    private func readBytes(_ n: Int) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: n)
        var got = 0
        while got < n {
            guard let s = inputStream else { throw VNCError.readFailed }
            let r = buf.withUnsafeMutableBufferPointer { ptr -> Int in
                return s.read(ptr.baseAddress! + got, maxLength: n - got)
            }
            if r <= 0 { throw VNCError.readFailed }
            got += r
        }
        return buf
    }
    private func readU8() throws -> UInt8 { try readBytes(1)[0] }
    private func readU16() throws -> UInt16 { let b = try readBytes(2); return UInt16(b[0])<<8 | UInt16(b[1]) }
    private func readU32() throws -> UInt32 {
        let b = try readBytes(4)
        return UInt32(b[0])<<24 | UInt32(b[1])<<16 | UInt32(b[2])<<8 | UInt32(b[3])
    }
    private func readI32() throws -> Int32 { Int32(bitPattern: try readU32()) }

    private func writeBytes(_ data: [UInt8]) throws {
        guard let out = outputStream else { throw VNCError.writeFailed }
        var offset = 0
        while offset < data.count {
            let remaining = data.count - offset
            var chunk = Array(data[offset..<data.count])
            let w = out.write(&chunk, maxLength: remaining)
            if w <= 0 { throw VNCError.writeFailed }
            offset += w
        }
    }

    private func be16(_ v: UInt16) -> [UInt8] { [UInt8(v>>8), UInt8(v&0xFF)] }
    private func be32(_ v: UInt32) -> [UInt8] { [UInt8(v>>24), UInt8((v>>16)&0xFF), UInt8((v>>8)&0xFF), UInt8(v&0xFF)] }
    private func u16(_ a: UInt8, _ b: UInt8) -> UInt32 { UInt32(a)<<8 | UInt32(b) }

    private func vlog(_ msg: String) { NSLog("[VMNexus] %@", msg) }
}
