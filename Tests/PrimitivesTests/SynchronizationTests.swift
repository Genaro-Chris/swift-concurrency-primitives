import XCTest

@testable import Primitives

final class SynchronizationTests: XCTestCase {

    func test_locked_over_async() async {
        @Locked var value = 1
        async let asyncTask = Task.detached {
            $value.updateWhileLocked {
                $0 += 18
            }
        }
        _ = await asyncTask.value
        XCTAssertEqual(value, 19)
    }

    func test_once() {
        var total = 0
        DispatchQueue.concurrentPerform(iterations: 6) { _ in
            Once.runOnce {
                total += 1
            }
        }
        XCTAssertEqual(total, 1)
    }

    func test_oncestate() {
        var total = 0
        let once = OnceState()
        DispatchQueue.concurrentPerform(iterations: 6) { _ in
            once.runOnce {
                total += 1
            }
        }
        XCTAssertEqual(total, 1)
    }

    func test_lock() {
        var total = 0
        let lock = Lock()
        DispatchQueue.concurrentPerform(iterations: 11) { index in
            lock.whileLocked {
                total += index
            }
        }
        XCTAssertEqual(total, 55)
    }

    func test_locked() {
        struct Student {
            var age: Int
            var scores: [Int]
        }
        let student = Locked(Student(age: 0, scores: []))
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            student.updateWhileLocked { student in
                student.scores.append(index)
            }
            if index == 9 {
                student.age = 18
            }
        }
        XCTAssertEqual(student.scores.count, 10)
        XCTAssertEqual(student.age, 18)
    }

    func test_locked_wrapper() {
        struct Student {
            var age: Int
            var scores: [Int]
        }
        @Locked var student = Student(age: 0, scores: [])
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            $student.updateWhileLocked { student in
                student.scores.append(index)
            }
            if index == 9 {
                student.age = 18
            }
        }
        XCTAssertEqual(student.scores.count, 10)
        XCTAssertEqual(student.age, 18)
    }

    func test_notifier() {
        let notifier = Notifier(size: 3)!
        @Locked var count = 0
        Task.detached {
            async let _ = withTaskGroup(of: Void.self) { group in
                for _ in 1 ... 3 {
                    group.addTask {
                        $count.updateWhileLocked { $0 += 1 }
                        notifier.notify()
                    }
                }
            }
        }
        notifier.waitForAll()
        XCTAssertEqual(count, 3)
    }
}
