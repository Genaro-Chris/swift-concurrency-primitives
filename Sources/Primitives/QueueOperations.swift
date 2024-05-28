enum QueueOperations {

    case execute(block: WorkItem)
    case wait(with: Barrier)
}