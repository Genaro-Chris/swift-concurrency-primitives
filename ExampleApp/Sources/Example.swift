import Foundation
import Primitives

/// a global variable isolated to `GlobalActor`
@GlobalActor var globalActorCounter = 0

// Uses the `OneShotChannel` to simulate a promise type
func getAsyncValueFromNonAsyncContext() {
    let channel: OneShotChannel<Int> = OneShotChannel<Int>()
    Task { [channel] in
        try await Task.sleep(for: .microseconds(200))
        channel <- await globalActorCounter
    }
    if let value: OneShotChannel<Int>.Element = <-channel {
        print("Got \(value)")
    }

}

@main
enum Program {
    static func main() async throws {

        replacesSwiftGlobalConcurrencyExecutor()

        Task { @GlobalActor in
            globalActorCounter += 10
        }

        getAsyncValueFromNonAsyncContext()

        await MainActor.run {
            print("This runs on the main actor as usual")
        }

        let specialActorInstance = SpecialActor()

        let lockInstance = LockActor()

        let normalActor = NormalActor()

        try await Task.sleep(nanoseconds: 2_000_500_000)

        await withDiscardingTaskGroup { group in
            for _ in 0...5 {
                group.addTask {
                    Task { @GlobalActor in globalActorCounter += 1 }
                    await specialActorInstance.increment(by: Int.random(in: 1...10))
                    await lockInstance.increment(by: Int.random(in: 1...10))
                    await normalActor.increment(by: Int.random(in: 1...10))
                }
            }
        }

        await Task.yield()

        try await Task.sleep(for: .microseconds(300), clock: .suspending)

        print("Count for \(type(of: specialActorInstance)): \(await specialActorInstance.count)")
        print("Count for \(type(of: lockInstance)): \(await lockInstance.count)")
        print("Count for \(type(of: normalActor)): \(await normalActor.count)")
        print("Count for globalActorCounter \(await globalActorCounter)")
    }
}
