import Foundation
import Primitives

/// a global variable isolated to `GlobalActor`
@GlobalActor var globalActorCounter = 0

/// Uses the `OneShotChannel` to simulate a promise type
func getAsyncValueFromNonAsyncContext() {
    let channel = OneShotChannel<Int>()
    Task { [channel] in
        try await Task.sleep(for: .microseconds(200))
        channel <- (await globalActorCounter)
    }
    if let value = <-channel {
        print("Got \(value)")
    }

}

@main
enum Program {
    static func main() async throws {

        replacesSwiftGlobalConcurrencyHook()

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

        async let group: () = withDiscardingTaskGroup { group in
            for _ in 0 ... 5 {
                group.addTask {
                    Task { @GlobalActor in globalActorCounter += 1 }
                    async let _ = specialActorInstance.increment(by: Int.random(in: 1 ... 10))
                    async let _ = lockInstance.increment(by: Int.random(in: 1 ... 10))
                    async let _ = normalActor.increment(by: Int.random(in: 1 ... 10))
                }
            }
        }

        await Task.yield()

        try await Task.sleep(for: .microseconds(300), clock: .suspending)

        await group

        print("Count for \(type(of: specialActorInstance)): \(await specialActorInstance.count)")
        print("Count for \(type(of: lockInstance)): \(await lockInstance.count)")
        print("Count for \(type(of: normalActor)): \(await normalActor.count)")
        print("Count for globalActorConter \(await globalActorCounter)")
    }
}
