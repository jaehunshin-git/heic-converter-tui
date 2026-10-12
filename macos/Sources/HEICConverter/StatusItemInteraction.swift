import AppKit

enum StatusItemInteraction {
    static func opensMenu(for event: NSEvent?) -> Bool {
        event?.type != .leftMouseUp || event?.modifierFlags.contains(.control) == true
    }

    /// 아이콘을 누르는 중 발생한 포커스 이동은 mouseUp의 토글에 맡긴다.
    static func defersPanelDismissal(buttonFrame: NSRect?, mouseLocation: NSPoint,
                                    pressedMouseButtons: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let buttonFrame else { return false }
        return pressedMouseButtons & 1 != 0 && !modifiers.contains(.control)
            && buttonFrame.contains(mouseLocation)
    }
}
