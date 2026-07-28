//
//  MainWindowCall.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/16.
//

import Cocoa
let kOriMainWindowHeight = 566-28 //
let kOriMainWindowWidth = 752
let kOriMainWindowMargin = 130
class MainWindowCall: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: kOriMainWindowWidth, height: kOriMainWindowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.minSize = NSSize(width: kOriMainWindowWidth, height: kOriMainWindowHeight)
        window.title = appName
        self.init(window: window)
    }
    
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.center()
            self?.window?.contentViewController = MainWindowController()
            self?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
