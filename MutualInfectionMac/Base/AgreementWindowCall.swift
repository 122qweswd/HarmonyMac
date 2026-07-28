//
//  AgreementWindowCall.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/16.
//

import Cocoa

class AgreementWindowCall: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 705, height: 499),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = appName
        self.init(window: window)
    }
    
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.center()
            self?.window?.contentViewController = AgreementWindowController()
            self?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
