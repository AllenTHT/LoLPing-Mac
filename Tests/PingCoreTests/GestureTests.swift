import Foundation
import CoreGraphics
import PingCore

private var failures = 0
private var assertions = 0
private func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    assertions += 1
    if actual != expected {
        failures += 1
        print("FAIL \(file):\(line): \(actual) != \(expected)")
    }
}

final class GestureTests {
    let chord: Modifiers = [.control, .option, .command]
    let anchor = CGPoint(x: 600, y: 400)

    func open(_ machine: GestureMachine) {
        XCTAssertEqual(machine.flagsChanged(chord, at: anchor, otherInputHeld: false), [.arm(anchor)])
        XCTAssertEqual(machine.delayElapsed(), [.show(anchor)])
    }
    func testEightDirectionsAndCentralDeadZone() {
        let vectors: [CGPoint] = [.init(x: 0,y: 100), .init(x: 100,y: 100), .init(x: 100,y: 0), .init(x: 100,y: -100),
                                  .init(x: 0,y: -100), .init(x: -100,y: -100), .init(x: -100,y: 0), .init(x: -100,y: 100)]
        for (index, vector) in vectors.enumerated() {
            XCTAssertEqual(WheelGeometry.selection(at: vector, center: .zero, deadZone: WheelGeometry.centerRadius), PingKind.wheel[index])
        }
        XCTAssertEqual(WheelGeometry.selection(at: CGPoint(x: 66, y: 0), center: .zero, deadZone: WheelGeometry.centerRadius), .generic)
        XCTAssertEqual(WheelGeometry.selection(at: CGPoint(x: 67, y: 0), center: .zero, deadZone: WheelGeometry.centerRadius), .onMyWay)
    }
    func testShortPressNeverPingsAndLateTimerDoesNothing() {
        let machine = GestureMachine()
        _ = machine.flagsChanged(chord, at: anchor, otherInputHeld: false)
        XCTAssertEqual(machine.flagsChanged([], at: anchor, otherInputHeld: false), [.hide])
        XCTAssertEqual(machine.delayElapsed(), [])
    }
    func testReleaseCommitsExactlyOnceAtOriginalAnchor() {
        let machine = GestureMachine(); open(machine)
        XCTAssertEqual(machine.moved(to: CGPoint(x: 500, y: 400)), [.hover(.missing, angle: -.pi/2)])
        XCTAssertEqual(machine.flagsChanged([.control, .option], at: .zero, otherInputHeld: false), [.dismiss, .commit(.missing, anchor)])
        XCTAssertEqual(machine.flagsChanged([.option], at: .zero, otherInputHeld: false), [])
        XCTAssertEqual(machine.flagsChanged([], at: .zero, otherInputHeld: false), [])
        XCTAssertEqual(machine.phase, .idle)
    }
    func testAllReleaseOrdersCommitExactlyOnce() {
        let keys: [Modifiers] = [.control, .option, .command]
        for first in keys {
            for second in keys where second != first {
                let machine = GestureMachine(); open(machine)
                var remaining = chord
                var commits = 0
                for key in [first, second] + keys.filter({ $0 != first && $0 != second }) {
                    remaining.subtract(key)
                    for action in machine.flagsChanged(remaining, at: anchor, otherInputHeld: false) {
                        if case .commit = action { commits += 1 }
                    }
                }
                XCTAssertEqual(commits, 1)
                XCTAssertEqual(machine.phase, .idle)
            }
        }
    }
    func testRepressingOneKeyDoesNotCreateSecondPing() {
        let machine = GestureMachine(); open(machine)
        _ = machine.flagsChanged([.control, .option], at: anchor, otherInputHeld: false)
        XCTAssertEqual(machine.flagsChanged(chord, at: anchor, otherInputHeld: false), [])
        XCTAssertEqual(machine.delayElapsed(), [])
        _ = machine.flagsChanged([], at: anchor, otherInputHeld: false)
        open(machine)
    }
    func testCancelAndOtherShortcutsRequireFullRelease() {
        let machine = GestureMachine(); open(machine)
        XCTAssertEqual(machine.cancel(), [.hide])
        XCTAssertEqual(machine.flagsChanged([.option], at: anchor, otherInputHeld: false), [])
        _ = machine.flagsChanged(chord, at: anchor, otherInputHeld: false)
        XCTAssertEqual(machine.delayElapsed(), [])
        _ = machine.flagsChanged([], at: anchor, otherInputHeld: false)
        open(machine)
    }
    func testFourthModifierCancelsInsteadOfCommitting() {
        let machine = GestureMachine(); open(machine)
        XCTAssertEqual(machine.flagsChanged([.control, .option, .command, .shift], at: anchor, otherInputHeld: false), [.hide])
        XCTAssertEqual(machine.flagsChanged([], at: anchor, otherInputHeld: false), [])
    }
    func testExistingDragOrKeyPressDoesNotArm() {
        let machine = GestureMachine()
        XCTAssertEqual(machine.flagsChanged(chord, at: anchor, otherInputHeld: true), [])
        XCTAssertEqual(machine.delayElapsed(), [])
        XCTAssertEqual(machine.phase, .blocked)
    }
    func testResetDuringAnimationCannotCommit() {
        let machine = GestureMachine(); open(machine)
        machine.reset()
        XCTAssertEqual(machine.flagsChanged([], at: anchor, otherInputHeld: false), [])
        XCTAssertEqual(machine.delayElapsed(), [])
    }
    func testEdgeClampingPreservesActualPingLocation() {
        let machine = GestureMachine()
        let edge = CGPoint(x: -1915, y: 1080)
        let display = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let center = WheelGeometry.clampedCenter(anchor: edge, frame: display, radius: 150)
        XCTAssertEqual(center, CGPoint(x: -1770, y: 930))
        _ = machine.flagsChanged(chord, at: edge, otherInputHeld: false)
        _ = machine.delayElapsed()
        XCTAssertEqual(machine.setWheelCenter(center), [])
        _ = machine.moved(to: CGPoint(x: center.x+90, y: center.y))
        XCTAssertEqual(machine.flagsChanged([], at: edge, otherInputHeld: false), [.dismiss, .commit(.onMyWay, edge)])
    }
    func testMovementDuringArmingAppliedAfterWheelOpens() {
        let machine = GestureMachine()
        _ = machine.flagsChanged(chord, at: anchor, otherInputHeld: false)
        _ = machine.moved(to: CGPoint(x: 600, y: 300))
        _ = machine.delayElapsed()
        XCTAssertEqual(machine.setWheelCenter(anchor), [.hover(.assist, angle: .pi)])
    }
    func testEveryConfigurableChord() {
        for trigger in TriggerChord.allCases {
            let machine = GestureMachine(); machine.chord = trigger
            XCTAssertEqual(machine.flagsChanged(trigger.modifiers, at: anchor, otherInputHeld: false), [.arm(anchor)])
            _ = machine.delayElapsed()
            XCTAssertEqual(machine.flagsChanged([], at: anchor, otherInputHeld: false), [.dismiss, .commit(.generic, anchor)])
        }
    }
    func testContinuousDirectionAndCenterReset() {
        let machine = GestureMachine(); open(machine)
        let first = CGPoint(x: 600, y: 500), second = CGPoint(x: 610, y: 500)
        XCTAssertEqual(machine.moved(to: first), [.hover(.retreat, angle: 0)])
        XCTAssertEqual(machine.moved(to: second), [.hover(.retreat, angle: atan2(10, 100))])
        XCTAssertEqual(machine.selected, .retreat)
        XCTAssertEqual(machine.moved(to: CGPoint(x: 600, y: 466)), [.hover(.generic, angle: nil)])
        XCTAssertEqual(machine.flagsChanged([], at: anchor, otherInputHeld: false), [.dismiss, .commit(.generic, anchor)])
        XCTAssertEqual(machine.moved(to: first), [])
    }
    func testScaledCenterMatchesVisualCircle() {
        for scale: CGFloat in [0.75, 1, 1.5] {
            let machine = GestureMachine(); machine.deadZone = WheelGeometry.centerRadius*scale; open(machine)
            XCTAssertEqual(machine.moved(to: CGPoint(x: anchor.x+66*scale, y: anchor.y)), [.hover(.generic, angle: nil)])
            XCTAssertEqual(machine.moved(to: CGPoint(x: anchor.x+66*scale+0.01, y: anchor.y)), [.hover(.onMyWay, angle: .pi/2)])
        }
    }
}

@main
enum Checks {
    static func main() {
        let test = GestureTests()
        let scenarios: [(String, () -> Void)] = [
            ("八向选择与中央区域", test.testEightDirectionsAndCentralDeadZone),
            ("短按不触发", test.testShortPressNeverPingsAndLateTimerDoesNothing),
            ("一次发送及原始落点", test.testReleaseCommitsExactlyOnceAtOriginalAnchor),
            ("所有松键顺序", test.testAllReleaseOrdersCommitExactlyOnce),
            ("重新按单键不重复发送", test.testRepressingOneKeyDoesNotCreateSecondPing),
            ("取消后必须完整松开", test.testCancelAndOtherShortcutsRequireFullRelease),
            ("额外修饰键取消", test.testFourthModifierCancelsInsteadOfCommitting),
            ("现有拖动或按键不触发", test.testExistingDragOrKeyPressDoesNotArm),
            ("关闭后不再提交", test.testResetDuringAnimationCannotCommit),
            ("外接屏坐标与贴边落点", test.testEdgeClampingPreservesActualPingLocation),
            ("延迟期间的鼠标移动", test.testMovementDuringArmingAppliedAfterWheelOpens),
            ("三种可选组合键", test.testEveryConfigurableChord),
            ("同扇区方向更新与中央复位", test.testContinuousDirectionAndCenterReset),
            ("缩放后中心判定与圆圈一致", test.testScaledCenterMatchesVisualCircle)
        ]
        for (name, scenario) in scenarios {
            let before = failures
            scenario()
            print("\(failures == before ? "PASS" : "FAIL") \(name)")
        }
        print("\(scenarios.count) scenarios, \(assertions) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
