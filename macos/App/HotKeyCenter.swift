import AppKit
import Carbon
import Foundation

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var toggle: (() -> Void)?
    private var capture: (() -> Void)?
    private var files: (() -> Void)?
    private var handler: EventHandlerRef?
    private var toggleRef: EventHotKeyRef?
    private var captureRef: EventHotKeyRef?
    private var filesRef: EventHotKeyRef?
    private(set) var toggleChord = HotKeyChord.toggleDefault
    private(set) var captureChord = HotKeyChord.captureDefault
    private(set) var filesChord = HotKeyChord.filesDefault
    private(set) var hideChord = HotKeyChord.hideDefault
    private(set) var pasteChord = HotKeyChord.pasteDefault
    private(set) var copyChord = HotKeyChord.copyDefault
    private(set) var deleteChord = HotKeyChord.deleteDefault

    @discardableResult
    func register(
        toggle: @escaping () -> Void,
        capture: @escaping () -> Void,
        files: @escaping () -> Void,
        toggleChord: HotKeyChord = .toggleDefault,
        captureChord: HotKeyChord = .captureDefault,
        filesChord: HotKeyChord = .filesDefault,
        hideChord: HotKeyChord = .hideDefault,
        pasteChord: HotKeyChord = .pasteDefault,
        copyChord: HotKeyChord = .copyDefault,
        deleteChord: HotKeyChord = .deleteDefault
    ) -> HotKeyAvailability {
        self.toggle = toggle
        self.capture = capture
        self.files = files
        self.toggleChord = toggleChord
        self.captureChord = captureChord
        self.filesChord = filesChord
        self.hideChord = hideChord
        self.pasteChord = pasteChord
        self.copyChord = copyChord
        self.deleteChord = deleteChord
        unregister()
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let pointer = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                DispatchQueue.main.async {
                    if hotKeyID.id == 1 { center.toggle?() }
                    if hotKeyID.id == 2 { center.capture?() }
                    if hotKeyID.id == 3 { center.files?() }
                }
                return noErr
            }, 1, &spec, pointer, &handler)
        }

        let toggleOK = toggleChord.hasModifier && RegisterEventHotKey(
            toggleChord.keyCode,
            toggleChord.carbonModifiers,
            EventHotKeyID(signature: OSType(0x44524131), id: 1),
            GetApplicationEventTarget(),
            0,
            &toggleRef
        ) == noErr
        let captureOK = captureChord.hasModifier && RegisterEventHotKey(
            captureChord.keyCode,
            captureChord.carbonModifiers,
            EventHotKeyID(signature: OSType(0x44524132), id: 2),
            GetApplicationEventTarget(),
            0,
            &captureRef
        ) == noErr
        let filesOK = filesChord.hasModifier && RegisterEventHotKey(
            filesChord.keyCode,
            filesChord.carbonModifiers,
            EventHotKeyID(signature: OSType(0x44524133), id: 3),
            GetApplicationEventTarget(),
            0,
            &filesRef
        ) == noErr
        return HotKeyAvailability(toggle: toggleOK, capture: captureOK, files: filesOK)
    }

    func unregister() {
        if let toggleRef {
            UnregisterEventHotKey(toggleRef)
            self.toggleRef = nil
        }
        if let captureRef {
            UnregisterEventHotKey(captureRef)
            self.captureRef = nil
        }
        if let filesRef {
            UnregisterEventHotKey(filesRef)
            self.filesRef = nil
        }
    }
}
