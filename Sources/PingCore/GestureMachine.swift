import Foundation
import CoreGraphics

/// Pure state machine. Platform code handles clocks, permissions and rendering.
public final class GestureMachine {
    public enum Phase: Equatable { case idle, arming, open, blocked }
    public enum Action: Equatable {
        case arm(CGPoint), show(CGPoint), hover(PingKind, angle: CGFloat?), hide, dismiss, commit(PingKind, CGPoint)
    }
    public private(set) var phase: Phase = .idle
    public private(set) var selected: PingKind = .generic
    public private(set) var anchor: CGPoint = .zero
    public private(set) var currentModifiers: Modifiers = []
    public var chord: TriggerChord = .controlOptionCommand
    public var deadZone: CGFloat = WheelGeometry.centerRadius
    private var center: CGPoint = .zero
    private var pointer: CGPoint = .zero
    public init() {}

    public func flagsChanged(_ flags: Modifiers, at point: CGPoint, otherInputHeld: Bool) -> [Action] {
        currentModifiers = flags
        if phase == .blocked {
            if flags.intersection(chord.modifiers).isEmpty { phase = .idle }
            return []
        }
        if phase == .idle {
            guard flags == chord.modifiers else { return [] }
            guard !otherInputHeld else { phase = .blocked; return [] }
            anchor = point; center = point; pointer = point; selected = .generic
            phase = .arming
            return [.arm(point)]
        }
        // Adding a fourth modifier is a different shortcut, never a commit.
        if !flags.subtracting(chord.modifiers).isEmpty { return cancel() }
        if flags != chord.modifiers {
            let wasOpen = phase == .open
            phase = flags.intersection(chord.modifiers).isEmpty ? .idle : .blocked
            return wasOpen ? [.dismiss, .commit(selected, anchor)] : [.hide]
        }
        return []
    }

    public func delayElapsed() -> [Action] {
        guard phase == .arming, currentModifiers == chord.modifiers else { return [] }
        phase = .open
        return [.show(anchor)]
    }

    public func setWheelCenter(_ point: CGPoint) -> [Action] {
        center = point
        // At an edge the wheel moves inwards, but the original Ping anchor stays fixed.
        guard hypot(pointer.x - anchor.x, pointer.y - anchor.y) > 4 else { return [] }
        return moved(to: pointer)
    }

    public func moved(to point: CGPoint) -> [Action] {
        pointer = point
        guard phase == .open else { return [] }
        let next = WheelGeometry.selection(at: point, center: center, deadZone: deadZone)
        selected = next
        return [.hover(next, angle: WheelGeometry.direction(at: point, center: center, deadZone: deadZone))]
    }

    public func cancel() -> [Action] {
        let hadGesture = phase == .arming || phase == .open
        phase = currentModifiers.intersection(chord.modifiers).isEmpty ? .idle : .blocked
        selected = .generic
        return hadGesture ? [.hide] : []
    }

    public func reset(blockUntilRelease: Bool = false) {
        phase = blockUntilRelease ? .blocked : .idle
        selected = .generic
        currentModifiers = []
    }
}
