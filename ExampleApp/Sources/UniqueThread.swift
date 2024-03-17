import Foundation

public typealias TaskItem = () -> Void

public typealias SendableTaskItem = @Sendable () -> Void

class UniqueThread: Thread {

    let condition = Condition()

    let mutex = Mutex()

    var array = [TaskItem]()

    func submit(_ body: @escaping TaskItem) {
        mutex.whileLocked {
            array.append(body)
            condition.signal()
        }
    }

    fileprivate func dequeue() -> TaskItem? {
        return mutex.whileLocked {
            condition.wait(mutex: mutex, condition: !array.isEmpty)
            guard !array.isEmpty else { return nil }
            return array.removeFirst()
        }
    }

    override func main() {
        while !self.isCancelled {
            if let work = self.dequeue() {
                work()
            }
        }
    }
}
