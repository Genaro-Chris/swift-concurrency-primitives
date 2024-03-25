import Foundation

final class UnnamedThread: Thread {

    let block: TaskItem

    init(_ block: @escaping TaskItem) {
        self.block = block
        super.init()
    }

    override func main() {
        block()
    }
}
