import class Foundation.Thread

final class UniqueThread: Thread {

    let taskChannel: TaskChannel

    init(channel: TaskChannel) {
        taskChannel = channel
        super.init()
    }

    func enqueue(_ task: @escaping WorkItem) {
        taskChannel.enqueue(task)
    }

    override func main() {
        while !isCancelled {
            while let task = taskChannel.dequeue() { task() }
        }
    }

    func end() {
        super.cancel()
        taskChannel.end()
    }

    override func cancel() {
        taskChannel.clear()
    }
}