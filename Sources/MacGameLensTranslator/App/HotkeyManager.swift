import AppKit
import Carbon
import os

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private weak var coordinator: LensTranslationCoordinator?
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "hotkey")

    private var hotKeyID = EventHotKeyID(signature: 0x4D474C54, id: 1) // "MGLT"
    private let defaultKeyCode: UInt32 = 17 // T key
    private let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    func configure(coordinator: LensTranslationCoordinator) {
        self.coordinator = coordinator
        registerHotkey(keyCode: defaultKeyCode, modifiers: defaultModifiers)
    }

    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        unregisterHotkey()

        var gHotKeyEventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkeyEvent()
                return noErr
            },
            1,
            &gHotKeyEventSpec,
            selfPtr,
            &eventHandlerRef
        )

        guard status == noErr else {
            logger.error("Failed to install event handler: \(status)")
            return
        }

        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
        if regStatus != noErr {
            logger.error("Failed to register hotkey: \(regStatus)")
        } else {
            logger.info("Hotkey registered successfully")
        }
    }

    func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
    }

    private func handleHotkeyEvent() {
        logger.debug("Hotkey pressed")
        Task { @MainActor in
            await coordinator?.toggleTranslation()
        }
    }
}
