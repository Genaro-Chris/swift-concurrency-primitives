enum QueueOperations {

    case ready(WorkItem)
    case wait(Barrier)
}
