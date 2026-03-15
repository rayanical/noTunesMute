//
//  AppDelegate.swift
//  noTunes
//
//  Created by Tom Taylor on 04/01/2017.
//  Copyright © 2017 Twisted Digital Ltd. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let defaults = UserDefaults.standard

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    @IBOutlet weak var statusMenu: NSMenu!

    private let faceTimeBundleID = "com.apple.FaceTime"
    private let faceTimeMuteStrategyDefaultsKey = "faceTimeMuteStrategy"

    private enum FaceTimeMuteStrategy: String, CaseIterable {
        case buttonDescription
        case buttonName
        case videoMenu
        case menuScan

        static let discoveryOrder: [FaceTimeMuteStrategy] = [
            .buttonDescription,
            .buttonName,
            .videoMenu,
            .menuScan
        ]
    }

    private let systemDefinedEventRawValue = UInt32(NSEvent.EventType.systemDefined.rawValue)
    private let mediaKeyEventSubtypeRawValue: Int16 = 8
    private let mediaKeyDownStateRawValue = 0xA
    private let nxKeyTypePlay = 16

    private let faceTimeAutomationQueue = DispatchQueue(label: "digital.twisted.noTunes.faceTimeAutomation", qos: .userInitiated)
    private let stateAccessQueue = DispatchQueue(label: "digital.twisted.noTunes.stateAccess", qos: .userInitiated)
    private var toggleInFlight = false
    private var learnedFaceTimeMuteStrategy: FaceTimeMuteStrategy?

    private var mediaKeyEventTap: CFMachPort?
    private var mediaKeyRunLoopSource: CFRunLoopSource?

    @IBAction func hideIconClicked(_ sender: NSMenuItem) {
        defaults.set(true, forKey: "hideIcon")
        NSStatusBar.system.removeStatusItem(statusItem)
        self.appIsLaunched()
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == NSEvent.EventType.rightMouseUp ||
           (event.type == NSEvent.EventType.leftMouseUp && event.modifierFlags.contains(NSEvent.ModifierFlags.control)) {
            statusItem.menu = statusMenu
            if let menu = statusItem.menu {
                menu.popUp(positioning: menu.items.first, at: NSEvent.mouseLocation, in: nil)
            }
            statusItem.menu = nil
        } else {
            if statusItem.button?.image == NSImage(named: "StatusBarButtonImage") {
                self.appIsLaunched()
                statusItem.button?.image = NSImage(named: "StatusBarButtonImageActive")
            } else {
                statusItem.button?.image = NSImage(named: "StatusBarButtonImage")
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.button?.image = NSImage(named: "StatusBarButtonImageActive")

        if let button = statusItem.button {
            button.action = #selector(self.statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if defaults.bool(forKey: "hideIcon") {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        self.loadFaceTimeMuteStrategyFromDefaults()
        self.checkPermissions()
        self.setupMediaKeyEventTap()
        self.appIsLaunched()
        self.createListener()
    }

    func createListener() {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: #selector(self.appWillLaunch(note:)), name: NSWorkspace.willLaunchApplicationNotification, object: nil)
    }

    func appIsLaunched() {
        let apps = NSWorkspace.shared.runningApplications
        for currentApp in apps.enumerated() {
            let runningApp = apps[currentApp.offset]

            if(runningApp.activationPolicy == .regular) {
                if(runningApp.bundleIdentifier == "com.apple.iTunes") {
                    runningApp.forceTerminate()
                }
                if(runningApp.bundleIdentifier == "com.apple.Music") {
                    runningApp.forceTerminate()
                }
            }
        }
    }

    @objc func appWillLaunch(note:Notification) {
        if statusItem.button?.image == NSImage(named: "StatusBarButtonImageActive") || defaults.bool(forKey: "hideIcon") {
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                if app.bundleIdentifier == "com.apple.Music" {
                    app.forceTerminate()
                    self.launchReplacement()
                }
                else if app.bundleIdentifier == "com.apple.iTunes" {
                    app.forceTerminate()
                    self.launchReplacement()
                }
            }
        }
    }

    func launchReplacement() {
        let replacement = defaults.string(forKey: "replacement");
        if (replacement != nil) {
            let task = Process()

            task.arguments = [replacement!];
            task.launchPath = "/usr/bin/open"
            task.launch()
        }
    }

    func terminateProcessWith(_ processId:Int,_ processName:String) {
        let process = NSRunningApplication.init(processIdentifier: pid_t(processId))
        process?.forceTerminate()
    }

    private func checkPermissions() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)

        if !isAccessibilityTrusted {
            NSLog("noTunes: Accessibility permission is required to intercept Play/Pause media keys.")
        }

        self.warmUpAppleEventsPermission()
    }

    private func warmUpAppleEventsPermission() {
        let source = """
        -- This lightweight script intentionally touches System Events once so macOS can
        -- present AppleEvents authorization prompt early (instead of during first key press).
        tell application "System Events"
            return UI elements enabled
        end tell
        """

        var error: NSDictionary?
        _ = NSAppleScript(source: source)?.executeAndReturnError(&error)

        if let error = error {
            NSLog("noTunes: AppleEvents permission may still be pending: \(error)")
        }
    }

    private func loadFaceTimeMuteStrategyFromDefaults() {
        guard let rawValue = defaults.string(forKey: faceTimeMuteStrategyDefaultsKey),
              let strategy = FaceTimeMuteStrategy(rawValue: rawValue) else {
            return
        }

        stateAccessQueue.sync {
            learnedFaceTimeMuteStrategy = strategy
        }
    }

    private func currentFaceTimeMuteStrategy() -> FaceTimeMuteStrategy? {
        return stateAccessQueue.sync {
            learnedFaceTimeMuteStrategy
        }
    }

    private func persistFaceTimeMuteStrategy(_ strategy: FaceTimeMuteStrategy) {
        defaults.set(strategy.rawValue, forKey: faceTimeMuteStrategyDefaultsKey)
        stateAccessQueue.sync {
            learnedFaceTimeMuteStrategy = strategy
        }
    }

    private func setupMediaKeyEventTap() {
        let eventMask =
            (CGEventMask(1) << CGEventMask(systemDefinedEventRawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.tapDisabledByTimeout.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.tapDisabledByUserInput.rawValue))

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
            return appDelegate.handleMediaKeyEvent(type: type, event: event)
        }

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            NSLog("noTunes: Failed to create media key event tap. Check Accessibility permissions.")
            return
        }

        mediaKeyEventTap = tap
        mediaKeyRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = mediaKeyRunLoopSource else {
            NSLog("noTunes: Failed to create media key event run loop source.")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func requestFaceTimeMuteToggle() {
        stateAccessQueue.async { [weak self] in
            guard let self = self else { return }
            if self.toggleInFlight {
                return
            }

            self.toggleInFlight = true
            self.faceTimeAutomationQueue.async { [weak self] in
                guard let self = self else { return }
                _ = self.performFaceTimeMuteToggle()
                self.stateAccessQueue.async { [weak self] in
                    self?.toggleInFlight = false
                }
            }
        }
    }

    private func handleMediaKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = mediaKeyEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type.rawValue == systemDefinedEventRawValue else {
            return Unmanaged.passUnretained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == mediaKeyEventSubtypeRawValue else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyState = (data1 & 0x0000FF00) >> 8

        guard keyCode == nxKeyTypePlay, keyState == mediaKeyDownStateRawValue else {
            return Unmanaged.passUnretained(event)
        }

        if isProtectionEnabled() {
            requestFaceTimeMuteToggle()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func isProtectionEnabled() -> Bool {
        if defaults.bool(forKey: "hideIcon") {
            return true
        }

        return statusItem.button?.image == NSImage(named: "StatusBarButtonImageActive")
    }

    private func performFaceTimeMuteToggle() -> Bool {
        guard runningApp(bundleID: faceTimeBundleID) != nil else {
            return false
        }

        if let cachedStrategy = currentFaceTimeMuteStrategy(),
           performFaceTimeMuteToggle(using: cachedStrategy) {
            return true
        }

        guard let discoveredStrategy = discoverAndPersistMuteStrategy() else {
            return false
        }

        return performFaceTimeMuteToggle(using: discoveredStrategy)
    }

    private func discoverAndPersistMuteStrategy() -> FaceTimeMuteStrategy? {
        for strategy in FaceTimeMuteStrategy.discoveryOrder {
            if probeFaceTimeMuteStrategy(strategy) {
                persistFaceTimeMuteStrategy(strategy)
                NSLog("noTunes: Learned FaceTime mute strategy \(strategy.rawValue).")
                return strategy
            }
        }

        return nil
    }

    private func probeFaceTimeMuteStrategy(_ strategy: FaceTimeMuteStrategy) -> Bool {
        let script = faceTimeProbeScript(for: strategy)
        return runFaceTimeScript(
            source: script,
            errorPrefix: "noTunes: FaceTime strategy probe (\(strategy.rawValue)) failed"
        )
    }

    private func performFaceTimeMuteToggle(using strategy: FaceTimeMuteStrategy) -> Bool {
        let script = faceTimeActionScript(for: strategy)
        return runFaceTimeScript(
            source: script,
            errorPrefix: "noTunes: FaceTime mute toggle (\(strategy.rawValue)) failed"
        )
    }

    private func runFaceTimeScript(source: String, errorPrefix: String) -> Bool {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

        if let error = error {
            NSLog("\(errorPrefix): \(error)")
            return false
        }

        return result?.booleanValue ?? false
    }

    private func faceTimeProbeScript(for strategy: FaceTimeMuteStrategy) -> String {
        switch strategy {
        case .buttonDescription:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false
                    tell process "FaceTime"
                        if (count of windows) is 0 then return false
                        set callWindow to front window

                        try
                            if exists (first button of callWindow whose description is "Mute") then return true
                        end try
                        try
                            if exists (first button of callWindow whose description is "Unmute") then return true
                        end try
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        case .buttonName:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false
                    tell process "FaceTime"
                        if (count of windows) is 0 then return false
                        set callWindow to front window

                        try
                            if exists (first button of callWindow whose name is "Mute") then return true
                        end try
                        try
                            if exists (first button of callWindow whose name is "Unmute") then return true
                        end try
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        case .videoMenu:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false
                    tell process "FaceTime"
                        if (count of windows) is 0 then return false
                        if not (exists menu bar item "Video" of menu bar 1) then return false

                        set videoMenu to menu 1 of menu bar item "Video" of menu bar 1
                        if exists menu item "Mute" of videoMenu then return true
                        if exists menu item "Unmute" of videoMenu then return true
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        case .menuScan:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false

                    tell process "FaceTime"
                        if (count of windows) is 0 then return false

                        repeat with menuBarItemRef in menu bar items of menu bar 1
                            try
                                set topMenuRef to menu 1 of menuBarItemRef

                                repeat with menuItemRef in menu items of topMenuRef
                                    set menuItemTitle to name of menuItemRef as text
                                    if menuItemTitle contains "Mute" or menuItemTitle contains "Unmute" then
                                        return true
                                    end if

                                    try
                                        repeat with subMenuItemRef in menu items of menu 1 of menuItemRef
                                            set subMenuItemTitle to name of subMenuItemRef as text
                                            if subMenuItemTitle contains "Mute" or subMenuItemTitle contains "Unmute" then
                                                return true
                                            end if
                                        end repeat
                                    end try
                                end repeat
                            end try
                        end repeat
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        }
    }

    private func faceTimeActionScript(for strategy: FaceTimeMuteStrategy) -> String {
        switch strategy {
        case .buttonDescription:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false
                    tell process "FaceTime"
                        if (count of windows) is 0 then return false
                        set callWindow to front window

                        try
                            click (first button of callWindow whose description is "Mute")
                            return true
                        end try
                        try
                            click (first button of callWindow whose description is "Unmute")
                            return true
                        end try
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        case .buttonName:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false
                    tell process "FaceTime"
                        if (count of windows) is 0 then return false
                        set callWindow to front window

                        try
                            click (first button of callWindow whose name is "Mute")
                            return true
                        end try
                        try
                            click (first button of callWindow whose name is "Unmute")
                            return true
                        end try
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        case .videoMenu:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false
                    tell process "FaceTime"
                        if (count of windows) is 0 then return false
                        if not (exists menu bar item "Video" of menu bar 1) then return false

                        set videoMenu to menu 1 of menu bar item "Video" of menu bar 1

                        if exists menu item "Mute" of videoMenu then
                            click menu item "Mute" of videoMenu
                            return true
                        end if

                        if exists menu item "Unmute" of videoMenu then
                            click menu item "Unmute" of videoMenu
                            return true
                        end if
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        case .menuScan:
            return """
            try
                tell application "System Events"
                    if not (exists process "FaceTime") then return false

                    tell process "FaceTime"
                        if (count of windows) is 0 then return false

                        repeat with menuBarItemRef in menu bar items of menu bar 1
                            try
                                set topMenuRef to menu 1 of menuBarItemRef

                                repeat with menuItemRef in menu items of topMenuRef
                                    set menuItemTitle to name of menuItemRef as text
                                    if menuItemTitle contains "Mute" or menuItemTitle contains "Unmute" then
                                        click menuItemRef
                                        return true
                                    end if

                                    try
                                        repeat with subMenuItemRef in menu items of menu 1 of menuItemRef
                                            set subMenuItemTitle to name of subMenuItemRef as text
                                            if subMenuItemTitle contains "Mute" or subMenuItemTitle contains "Unmute" then
                                                click subMenuItemRef
                                                return true
                                            end if
                                        end repeat
                                    end try
                                end repeat
                            end try
                        end repeat
                    end tell
                end tell
            on error
                return false
            end try

            return false
            """
        }
    }

    private func runningApp(bundleID: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleID && !$0.isTerminated
        }
    }

}
