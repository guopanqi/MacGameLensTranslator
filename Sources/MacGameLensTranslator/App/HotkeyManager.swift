import AppKit
import Carbon
import os

final class HotkeyManager {
    private var regionHotkeyRef: EventHotKeyRef?
    private var focusedWindowHotkeyRef: EventHotKeyRef?
    private var regionControlHotkeyRef: EventHotKeyRef?
    private var clearOverlayHotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private weak var coordinator: LensTranslationCoordinator?
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "hotkey")

    private let signature: OSType = 0x4D474C54 // "MGLT"
    private let regionHotkeyID: UInt32 = 1
    private let focusedWindowHotkeyID: UInt32 = 2
    private let regionControlHotkeyID: UInt32 = 3
    private let clearOverlayHotkeyID: UInt32 = 4
    private let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    func configure(coordinator: LensTranslationCoordinator) {
        self.coordinator = coordinator
        registerHotkeys()
    }

    func registerHotkeys() {
        unregisterHotkey()

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

        guard status == noErr else {
            logger.error("Failed to install event handler: \(status)")
            return
        }

        let regionID = EventHotKeyID(signature: signature, id: regionHotkeyID)
        let regionStatus = RegisterEventHotKey(17, defaultModifiers, regionID, GetApplicationEventTarget(), 0, &regionHotkeyRef) // T
        if regionStatus != noErr {
            logger.error("Failed to register region hotkey: \(regionStatus)")
        } else {
            logger.info("Region hotkey registered successfully")
        }

        let focusedWindowID = EventHotKeyID(signature: signature, id: focusedWindowHotkeyID)
        let focusedStatus = RegisterEventHotKey(13, defaultModifiers, focusedWindowID, GetApplicationEventTarget(), 0, &focusedWindowHotkeyRef) // W
        if focusedStatus != noErr {
            logger.error("Failed to register focused window hotkey: \(focusedStatus)")
        } else {
            logger.info("Focused window hotkey registered successfully")
        }

        let regionControlID = EventHotKeyID(signature: signature, id: regionControlHotkeyID)
        let regionControlStatus = RegisterEventHotKey(15, defaultModifiers, regionControlID, GetApplicationEventTarget(), 0, &regionControlHotkeyRef) // R
        if regionControlStatus != noErr {
            logger.error("Failed to register region control hotkey: \(regionControlStatus)")
        } else {
            logger.info("Region control hotkey registered successfully")
        }

        let clearOverlayID = EventHotKeyID(signature: signature, id: clearOverlayHotkeyID)
        let clearStatus = RegisterEventHotKey(8, defaultModifiers, clearOverlayID, GetApplicationEventTarget(), 0, &clearOverlayHotkeyRef) // C
        if clearStatus != noErr {
            logger.error("Failed to register clear overlay hotkey: \(clearStatus)")
        } else {
            logger.info("Clear overlay hotkey registered successfully")
        }
    }

    func unregisterHotkey() {
        if let ref = regionHotkeyRef {
            UnregisterEventHotKey(ref)
            regionHotkeyRef = nil
        }
        if let ref = focusedWindowHotkeyRef {
            UnregisterEventHotKey(ref)
            focusedWindowHotkeyRef = nil
        }
        if let ref = regionControlHotkeyRef {
            UnregisterEventHotKey(ref)
            regionControlHotkeyRef = nil
        }
        if let ref = clearOverlayHotkeyRef {
            UnregisterEventHotKey(ref)
            clearOverlayHotkeyRef = nil
        }
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

        Task { @MainActor in
            switch hotkeyID.id {
            case focusedWindowHotkeyID:
                logger.debug("Focused window hotkey pressed")
                await coordinator?.translateFocusedWindow()
            case regionControlHotkeyID:
                logger.debug("Region control hotkey pressed")
                coordinator?.showRegionControlMode()
            case clearOverlayHotkeyID:
                logger.debug("Clear overlay hotkey pressed")
                await coordinator?.clearOverlay()
            default:
                logger.debug("Region hotkey pressed")
                await coordinator?.toggleTranslation()
            }
        }
    }
}
