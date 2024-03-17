import Foundation

final class NamedThread: Thread {

    let threadName: String

    let block: TaskItem

    override var name: String? {
        get { threadName }
        set {}
    }

    init(name: String, _ block: @escaping TaskItem) {
        threadName = name
        self.block = block
        super.init()
    }

    override func main() {
        block()
    }
}
