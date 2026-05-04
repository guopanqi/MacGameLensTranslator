import AppKit
import Carbon
import os

enum HotkeyAction: UInt32, CaseIterable {
    case translateRegion = 1
    case translateWindow = 2
    case translateFullScreen = 3
    case clearOverlay = 4
    case showLastOverlay = 5
}

final class HotkeyManager {
    private var hotkeyRefs: [HotkeyAction: EventHotKeyRef?] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private weak var coordinator: LensTranslationCoordinator?
    private let settingsStore: SettingsStore
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "hotkey")

    private let signature: OSType = 0x4D474C54

    private var keyCodeMap: [String: UInt32] {
        [
            "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5,
            "Z": 6, "X": 7, "C": 8, "V": 9,
            "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15,
            "Y": 16, "T": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
            "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "O": 31, "U": 32, "[": 33, "I": 34, "P": 35,
            "L": 37, "J": 38, "'": 39, "K": 40, ";": 41, "\\": 42,
            ",": 43, "/": 44, "N": 45, "M": 46, ".": 47,
            "Space": 49,
        ]
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func configure(coordinator: LensTranslationCoordinator) {
        self.coordinator = coordinator
        registerHandler()
        registerHotkeys()
    }

    func reloadShortcuts() {
        unregisterHotkeys()
        registerHotkeys()
    }

    private func registerHandler() {
        if eventHandlerRef != nil { return }

        var gHotKeyEventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkeyEvent(event)
                return noErr
            },
            1,
            &gHotKeyEventSpec,
            selfPtr,
            &eventHandlerRef
        )

        if status != noErr {
            logger.error("Failed to install event handler: \(status)")
        }
    }

    private func registerHotkeys() {
        let s = settingsStore.settings
        let mappings: [(HotkeyAction, String)] = [
            (.translateRegion, s.regionHotkey),
            (.translateWindow, s.windowHotkey),
            (.translateFullScreen, s.fullScreenHotkey),
            (.clearOverlay, s.clearOverlayHotkey),
            (.showLastOverlay, s.showLastOverlayHotkey),
        ]

        for (action, shortcutString) in mappings {
            guard !shortcutString.isEmpty else { continue }
            guard let (keyCode, modifiers) = parseShortcut(shortcutString) else {
                logger.error("Failed to parse shortcut: \(shortcutString)")
                continue
            }

            var ref: EventHotKeyRef?
            let hotkeyID = EventHotKeyID(signature: signature, id: action.rawValue)
            let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                hotkeyRefs[action] = ref
                logger.info("Registered hotkey for \(action.rawValue): \(shortcutString)")
            } else {
                logger.error("Failed to register hotkey for \(action.rawValue): \(status)")
            }
        }
    }

    func unregisterHotkeys() {
        for (_, ref) in hotkeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotkeyRefs.removeAll()
    }

    func unregisterAll() {
        unregisterHotkeys()
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
    }

    private func handleHotkeyEvent(_ event: EventRef?) {
        var hotkeyID = EventHotKeyID()
        if let event {
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )
        }

        guard let action = HotkeyAction(rawValue: hotkeyID.id) else { return }

        Task { @MainActor in
            switch action {
            case .translateRegion:
                logger.debug("Translate region hotkey pressed")
                await coordinator?.toggleTranslation()
            case .translateWindow:
                logger.debug("Translate window hotkey pressed")
                await coordinator?.translateFocusedWindow()
            case .translateFullScreen:
                logger.debug("Translate full screen hotkey pressed")
                await coordinator?.translateFullScreen()
            case .clearOverlay:
                logger.debug("Clear overlay hotkey pressed")
                await coordinator?.clearOverlay()
            case .showLastOverlay:
                logger.debug("Show last overlay hotkey pressed")
                await coordinator?.showLastOverlay()
            }
        }
    }

    private func parseShortcut(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        let parts = shortcut.components(separatedBy: " + ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, let keyPart = parts.last else { return nil }

        guard let keyCode = keyCodeMap[keyPart.uppercased()] else { return nil }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            switch part.lowercased() {
            case "command": modifiers |= UInt32(cmdKey)
            case "shift": modifiers |= UInt32(shiftKey)
            case "option", "alt": modifiers |= UInt32(optionKey)
            case "control", "ctrl": modifiers |= UInt32(controlKey)
            default: break
            }
        }

        guard modifiers != 0 else { return nil }

        return (keyCode, modifiers)
    }
}
