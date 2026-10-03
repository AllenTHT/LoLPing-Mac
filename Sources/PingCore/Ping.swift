import Foundation
import CoreGraphics

public enum PingKind: String, CaseIterable, Identifiable {
    case retreat, push, onMyWay, allIn, assist, needVision, missing, enemyVision, generic
    public var id: String { rawValue }
    public static let wheel: [PingKind] = [.retreat, .push, .onMyWay, .allIn, .assist, .needVision, .missing, .enemyVision]
    public var title: String {
        switch self {
        case .retreat: return "撤退"
        case .push: return "推进"
        case .onMyWay: return "正在路上"
        case .allIn: return "全力进攻"
        case .assist: return "请求协助"
        case .needVision: return "需要视野"
        case .missing: return "敌人消失"
        case .enemyVision: return "敌方视野"
        case .generic: return "普通信号"
        }
    }
    public var iconName: String {
        switch self {
        case .retreat: return "retreat"
        case .push: return "push"
        case .onMyWay: return "on_my_way_new"
        case .allIn: return "all_in"
        case .assist: return "assist"
        case .needVision: return "need_ward"
        case .missing: return "mia_new"
        case .enemyVision: return "area_is_warded_small_red_new"
        case .generic: return "ping"
        }
    }
    public var soundName: String {
        switch self {
        case .retreat: return "retreat"
        case .push: return "push"
        case .onMyWay: return "on_my_way"
        case .allIn: return "all_in"
        case .assist: return "assist_me"
        case .needVision: return "need_vision"
        case .missing: return "q_mark"
        case .enemyVision: return "enemy_vision"
        case .generic: return "alert"
        }
    }
}

public struct Modifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let control = Modifiers(rawValue: 1)
    public static let option = Modifiers(rawValue: 2)
    public static let command = Modifiers(rawValue: 4)
    public static let shift = Modifiers(rawValue: 8)
}

public enum TriggerChord: String, CaseIterable, Identifiable {
    case controlOptionCommand, controlOptionShift, controlCommandShift
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .controlOptionCommand: return "⌃ ⌥ ⌘  Control + Option + Command"
        case .controlOptionShift: return "⌃ ⌥ ⇧  Control + Option + Shift"
        case .controlCommandShift: return "⌃ ⌘ ⇧  Control + Command + Shift"
        }
    }
    public var symbols: String {
        switch self {
        case .controlOptionCommand: return "⌃  ⌥  ⌘"
        case .controlOptionShift: return "⌃  ⌥  ⇧"
        case .controlCommandShift: return "⌃  ⌘  ⇧"
        }
    }
    public var modifiers: Modifiers {
        switch self {
        case .controlOptionCommand: return [.control, .option, .command]
        case .controlOptionShift: return [.control, .option, .shift]
        case .controlCommandShift: return [.control, .command, .shift]
        }
    }
}

public enum WheelGeometry {
    public static let centerRadius: CGFloat = 66
    public static let iconRadius: CGFloat = 101
    public static let outerRadius: CGFloat = 140

    /// Clockwise from north; nil in the ordinary Ping region.
    public static func direction(at point: CGPoint, center: CGPoint, deadZone: CGFloat) -> CGFloat? {
        let dx = point.x - center.x, dy = point.y - center.y
        guard hypot(dx, dy) > deadZone else { return nil }
        return atan2(dx, dy)
    }
    /// Coordinates use the AppKit convention: y increases upwards.
    public static func selection(at point: CGPoint, center: CGPoint, deadZone: CGFloat) -> PingKind {
        let dx = point.x - center.x, dy = point.y - center.y
        guard hypot(dx, dy) > deadZone else { return .generic }
        let clockwiseFromNorth = atan2(dx, dy)
        let index = Int(floor((clockwiseFromNorth + .pi / 8) / (.pi / 4)))
        return PingKind.wheel[(index % 8 + 8) % 8]
    }

    public static func clampedCenter(anchor: CGPoint, frame: CGRect, radius: CGFloat) -> CGPoint {
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            low > high ? (low + high) / 2 : min(max(value, low), high)
        }
        return CGPoint(x: clamp(anchor.x, frame.minX + radius, frame.maxX - radius),
                       y: clamp(anchor.y, frame.minY + radius, frame.maxY - radius))
    }
}
