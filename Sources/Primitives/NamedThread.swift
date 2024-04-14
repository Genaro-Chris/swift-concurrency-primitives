import class Foundation.Thread

final class NamedThread: Thread {

    let threadName: String

    override var name: String? {
        get { threadName }
        set {}
    }

    let latch: Latch

    let block: WorkItem

    init(_ name: String, _ body: @escaping WorkItem) {
        threadName = name
        latch = Latch(size: 1)
        block = body
        super.init()
    }

    override func main() {
        block()
        latch.decrementAndWait()
    }

    func join() {
        latch.waitForAll()
    }

}