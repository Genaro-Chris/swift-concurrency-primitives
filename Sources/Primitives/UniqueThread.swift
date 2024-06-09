import class Foundation.Thread

struct UniqueThread {

    let taskChannel: TaskChannel

    let threadHandle: Thread

    init(channel: TaskChannel) {
        taskChannel = channel
        threadHandle = Thread {
            while !Thread.current.isCancelled {
                while let task = channel.dequeue() { task() }
            }
        }
    }

    func enqueue(_ task: @escaping WorkItem) {
        taskChannel.enqueue(task)
    }

    func end() {
        threadHandle.cancel()
        taskChannel.end()
    }

    func cancel() {
        taskChannel.clear()
    }

    func start() {
        threadHandle.start()
    }
}
