//
//  VMStartSerialTerminal.swift
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//
//  Terminal view for VM serial port — connects to a TCP socket
//  (QEMU serial redirected to telnet:localhost:PORT) and provides
//  a basic ANSI terminal display with keyboard input.
//

import Cocoa

@objc public class VMStartSerialTerminal: NSView {

    @objc public var isConnected = false
    @objc public var onConnected: (() -> Void)?
    @objc public var onDisconnected: (() -> Void)?

    private var host = "127.0.0.1"
    private var port = 4321
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var worker: Thread?
    private var running = false

    // Terminal buffer
    private var lines: [String] = []
    private var currentLine = ""
    private let maxLines = 5000
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var inputField: NSTextField!
    private let lock = NSLock()

    // ANSI state (basic support)
    private var cursorRow = 0
    private var cursorCol = 0

    // ─── Init ───

    public override init(frame f: NSRect) { super.init(frame: f); setup() }
    required init?(coder c: NSCoder) { super.init(coder: c); setup() }

    private func setup() {
        // Scroll view with text view
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont(name: "Menlo", size: 12)
        textView.textColor = NSColor(red: 0.7, green: 0.94, blue: 0.7, alpha: 1.0)
        textView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        scrollView.documentView = textView
        addSubview(scrollView)

        // Input field at bottom
        let inputHeight: CGFloat = 28
        inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: bounds.width, height: inputHeight))
        inputField.autoresizingMask = [.width]
        inputField.font = NSFont(name: "Menlo", size: 12)
        inputField.placeholderString = "Type command and press Enter..."
        inputField.target = self
        inputField.action = #selector(sendInput)
        inputField.isBezeled = true
        inputField.bezelStyle = .roundedBezel
        addSubview(inputField)

        // Adjust scroll view to leave room for input
        scrollView.frame = NSRect(x: 0, y: inputHeight,
            width: bounds.width, height: bounds.height - inputHeight)
        scrollView.autoresizingMask = [.width, .height]

        appendLine("VMStart Serial Terminal")
        appendLine("Waiting for connection...")
    }

    override public func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        let inputH: CGFloat = 28
        scrollView.frame = NSRect(x: 0, y: inputH, width: bounds.width, height: bounds.height - inputH)
        inputField.frame = NSRect(x: 0, y: 0, width: bounds.width, height: inputH)
    }

    // ─── Connect / Disconnect ───

    @objc public func connect(host h: String = "127.0.0.1", port p: Int = 4321) {
        disconnect()
        host = h; port = p; running = true
        worker = Thread(target: self, selector: #selector(run), object: nil)
        worker?.name = "Serial"
        worker?.qualityOfService = .userInteractive
        worker?.start()
    }

    @objc public func disconnect() {
        running = false; isConnected = false
        inputStream?.close(); outputStream?.close()
        inputStream = nil; outputStream = nil
        worker?.cancel(); worker = nil
        DispatchQueue.main.async { [weak self] in
            self?.appendLine("[Disconnected]")
            self?.onDisconnected?()
        }
    }

    @objc private func run() {
        autoreleasepool {
            do {
                try openSocket()
                isConnected = true
                DispatchQueue.main.async { [weak self] in
                    self?.appendLine("[Connected to serial port \(self?.port ?? 0)]")
                    self?.onConnected?()
                }
                try readLoop()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.appendLine("[Error: \(error)]")
                }
            }
            isConnected = false
            DispatchQueue.main.async { [weak self] in self?.onDisconnected?() }
        }
    }

    private func openSocket() throws {
        var rs: Unmanaged<CFReadStream>?, ws: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, UInt32(port), &rs, &ws)
        guard let inp = rs?.takeRetainedValue() as InputStream?,
              let out = ws?.takeRetainedValue() as OutputStream? else {
            throw NSError(domain: "Serial", code: 1, userInfo: [NSLocalizedDescriptionKey: "Socket creation failed"])
        }
        inputStream = inp; outputStream = out
        inp.open(); out.open()
        for _ in 0..<50 {
            if inp.streamStatus == .open { break }
            if inp.streamStatus == .error || inp.streamStatus == .closed {
                throw NSError(domain: "Serial", code: 2, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func readLoop() throws {
        var buf = [UInt8](repeating: 0, count: 4096)
        while running && !Thread.current.isCancelled {
            guard let inp = inputStream, inp.hasBytesAvailable else {
                Thread.sleep(forTimeInterval: 0.01); continue
            }
            let n = inp.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            let data = Data(buf[0..<n])
            if let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                processANSI(str)
            }
        }
    }

    // ─── ANSI Processing (basic) ───

    private func processANSI(_ text: String) {
        // Strip ANSI escape sequences for basic display
        let cleaned = text.replacingOccurrences(
            of: "\\e\\[[0-9;]*[a-zA-Z]",
            with: "", options: .regularExpression)
        let cleaned2 = cleaned.replacingOccurrences(
            of: "\\e\\([a-zA-Z]", with: "", options: .regularExpression)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for ch in cleaned2 {
                if ch == "\r" { continue }
                if ch == "\n" {
                    self.flushLine()
                } else if ch == "\u{08}" {  // Backspace
                    if !self.currentLine.isEmpty {
                        self.currentLine.removeLast()
                    }
                } else {
                    self.currentLine.append(ch)
                }
            }
            self.refreshDisplay()
        }
    }

    private func flushLine() {
        lock.lock()
        lines.append(currentLine)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        currentLine = ""
        lock.unlock()
    }

    private func appendLine(_ text: String) {
        lock.lock()
        lines.append(text)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        lock.unlock()
        refreshDisplay()
    }

    private func refreshDisplay() {
        lock.lock()
        var allLines = lines
        if !currentLine.isEmpty { allLines.append(currentLine) }
        lock.unlock()
        let text = allLines.joined(separator: "\n")
        textView.string = text
        textView.scrollRangeToVisible(NSRange(location: text.count, length: 0))
    }

    // ─── Send Input ───

    @objc private func sendInput() {
        let text = inputField.stringValue
        inputField.stringValue = ""
        guard isConnected, let out = outputStream else {
            appendLine("[Not connected]")
            return
        }
        let data = (text + "\r\n").data(using: .utf8) ?? Data()
        var bytes = [UInt8](data)
        let sent = out.write(&bytes, maxLength: bytes.count)
        if sent <= 0 {
            appendLine("[Send failed]")
        }
    }

    /// Send raw data (for programmatic use)
    @objc public func sendData(_ data: Data) {
        guard isConnected, let out = outputStream else { return }
        var bytes = [UInt8](data)
        let _ = out.write(&bytes, maxLength: bytes.count)
    }

    /// Send a string
    @objc public func sendString(_ str: String) {
        if let data = str.data(using: .utf8) { sendData(data) }
    }

    /// Clear the terminal display
    @objc public func clearScreen() {
        lock.lock()
        lines.removeAll()
        currentLine = ""
        lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.refreshDisplay() }
    }
}
