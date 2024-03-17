import Foundation

struct RandomGenerator {

    var filled: [Int]

    let max: Int

    init(to size: Int) {
        max = size
        filled = (0..<max).shuffled()
    }

    mutating func random() -> Int {
        if filled.isEmpty {
            filled = (0..<max).shuffled()
            return filled.removeFirst()
        }
        return filled.removeFirst()
    }

}
