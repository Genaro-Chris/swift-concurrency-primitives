//
//  CwlDeque.swift
//  CwlUtils
//
//  Created by Matt Gallagher on 2016/09/13.
//  Copyright © 2016 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

import Foundation

/// This is a basic "circular-buffer" style Double-Ended Queue.
struct Deque<T>: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    typealias Index = Int
    typealias Indices = CountableRange<Int>
    typealias Element = T

    private let overAllocateFactor: Int = 2
    private let downsizeTriggerFactor: Int = 16
    private let defaultMinimumCapacity: Int = 5

    private var buffer: DequeBuffer<T>? = nil
    private var minCapacity: Int

    /// Implementation of RangeReplaceableCollection function
    init() {
        self.minCapacity = defaultMinimumCapacity
    }

    /// Allocate with a minimum capacity
    init(minCapacity: Int) {
        self.minCapacity = minCapacity
    }

    /// Implementation of RandomAccessCollection function
    subscript(_ at: Index) -> T {
        get {
            return buffer!.withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>)
                    -> T in
                precondition(at >= 0 && at < headerPtr.pointee.count)
                var offset: Int = headerPtr.pointee.offset + at
                if offset >= headerPtr.pointee.capacity {
                    offset -= headerPtr.pointee.capacity
                }
                return bodyPtr[offset]
            }
        }
        set {
            buffer!.withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>) in
                precondition(at >= 0 && at < headerPtr.pointee.count)
                var offset: Int = headerPtr.pointee.offset + at
                if offset >= headerPtr.pointee.capacity {
                    offset -= headerPtr.pointee.capacity
                }
                bodyPtr[offset] = newValue
            }
        }
    }

    /// Implementation of Collection function
    var startIndex: Index {
        return 0
    }

    /// Implementation of Collection function
    var endIndex: Index {
        return buffer?.withUnsafeMutablePointerToHeader {
            (headerPtr: UnsafeMutablePointer<DequeHeader>) in headerPtr.pointee.count
        }
            ?? 0
    }

    /// Implementation of Collection function
    var isEmpty: Bool {
        return buffer?.withUnsafeMutablePointerToHeader {
            (headerPtr: UnsafeMutablePointer<DequeHeader>) in headerPtr.pointee.count == 0
        } ?? true
    }

    /// Implementation of Collection function
    var count: Int {
        return endIndex
    }

    /// Optimized implementation of RangeReplaceableCollection function
    mutating func append(_ newElement: T) {
        let done: Bool =
            buffer?.withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>)
                    -> Bool in
                guard headerPtr.pointee.capacity >= headerPtr.pointee.count + 1 else {
                    return false
                }
                var index: Int = headerPtr.pointee.offset + headerPtr.pointee.count
                if index >= headerPtr.pointee.capacity {
                    index -= headerPtr.pointee.capacity
                }
                bodyPtr.advanced(by: index).initialize(to: newElement)
                headerPtr.pointee.count += 1
                return true
            } ?? false

        if !done {
            let index: Int = endIndex
            replaceSubrange(index..<index, with: CollectionOfOne(newElement))
        }
    }

    /// Optimized implementation of RangeReplaceableCollection function
    mutating func remove(at: Int) {
        let done: Bool =
            buffer?.withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>)
                    -> Bool in
                if at == headerPtr.pointee.count - 1 {
                    headerPtr.pointee.count -= 1
                    return true
                } else if at == 0, headerPtr.pointee.count > 0 {
                    headerPtr.pointee.offset += 1
                    if headerPtr.pointee.offset >= headerPtr.pointee.capacity {
                        headerPtr.pointee.offset -= headerPtr.pointee.capacity
                    }
                    headerPtr.pointee.count -= 1
                    return true
                }
                return false
            } ?? false

        if !done {
            replaceSubrange(at...at, with: EmptyCollection())
        }
    }

    /// Optimized implementation of RangeReplaceableCollection function
    mutating func removeFirst() -> T {
        return buffer!.withUnsafeMutablePointers {
            (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>) -> T in
            precondition(headerPtr.pointee.count > 0, "Index beyond bounds")
            let result: T = bodyPtr[headerPtr.pointee.offset]
            bodyPtr.advanced(by: headerPtr.pointee.offset).deinitialize(count: 1)
            headerPtr.pointee.offset += 1
            if headerPtr.pointee.offset >= headerPtr.pointee.capacity {
                headerPtr.pointee.offset -= headerPtr.pointee.capacity
            }
            headerPtr.pointee.count -= 1
            return result
        }
    }

    // Used when removing a range from the collection or deiniting self.
    private static func deinitialize(
        range: CountableRange<Int>, header: UnsafeMutablePointer<DequeHeader>,
        body: UnsafeMutablePointer<T>
    ) {
        let splitRange: (low: CountableRange<Int>, high: CountableRange<Int>) = header.pointee
            .splitRangeIndices(inRange: range)
        body.advanced(by: splitRange.low.startIndex).deinitialize(count: splitRange.low.count)
        body.advanced(by: splitRange.high.startIndex).deinitialize(count: splitRange.high.count)
    }

    // Move from an initialized to an uninitialized location, deinitializing the source.
    //
    // NOTE: the terms "preMapped" and "postMapped" are used. "preMapped" refer to the indices exposed by this type (zero based, contiguous), and "postMapped" refers to internal offsets within the buffer (not necessarily zero based and may wrap around). This function will only handle a single, contiguous block of "postMapped" indices so the caller must ensure that this function is invoked separately for each contiguous block.
    private static func moveInitialize(
        preMappedSourceRange: CountableRange<Int>, postMappedDestinationRange: CountableRange<Int>,
        sourceHeader: UnsafeMutablePointer<DequeHeader>, sourceBody: UnsafeMutablePointer<T>,
        destinationBody: UnsafeMutablePointer<T>
    ) {
        let sourceSplitRange: (low: CountableRange<Int>, high: CountableRange<Int>) = sourceHeader
            .pointee.splitRangeIndices(inRange: preMappedSourceRange)

        assert(
            sourceSplitRange.low.startIndex >= 0
                && (sourceSplitRange.low.startIndex < sourceHeader.pointee.capacity
                    || sourceSplitRange.low.startIndex == sourceSplitRange.low.endIndex)
        )
        assert(
            sourceSplitRange.low.endIndex >= 0
                && sourceSplitRange.low.endIndex <= sourceHeader.pointee.capacity)

        assert(
            sourceSplitRange.high.startIndex >= 0
                && (sourceSplitRange.high.startIndex < sourceHeader.pointee.capacity
                    || sourceSplitRange.high.startIndex == sourceSplitRange.high.endIndex)
        )
        assert(
            sourceSplitRange.high.endIndex >= 0
                && sourceSplitRange.high.endIndex <= sourceHeader.pointee.capacity)

        destinationBody.advanced(by: postMappedDestinationRange.startIndex).moveInitialize(
            from: sourceBody.advanced(by: sourceSplitRange.low.startIndex),
            count: sourceSplitRange.low.count)
        destinationBody.advanced(
            by: postMappedDestinationRange.startIndex + sourceSplitRange.low.count
        ).moveInitialize(
            from: sourceBody.advanced(by: sourceSplitRange.high.startIndex),
            count: sourceSplitRange.high.count)
    }

    // Copy from an initialized to an uninitialized location, leaving the source initialized.
    //
    // NOTE: the terms "preMapped" and "postMapped" are used. "preMapped" refer to the indices exposed by this type (zero based, contiguous), and "postMapped" refers to internal offsets within the buffer (not necessarily zero based and may wrap around). This function will only handle a single, contiguous block of "postMapped" indices so the caller must ensure that this function is invoked separately for each contiguous block.
    private static func copyInitialize(
        preMappedSourceRange: CountableRange<Int>, postMappedDestinationRange: CountableRange<Int>,
        sourceHeader: UnsafeMutablePointer<DequeHeader>, sourceBody: UnsafeMutablePointer<T>,
        destinationBody: UnsafeMutablePointer<T>
    ) {
        let sourceSplitRange: (low: CountableRange<Int>, high: CountableRange<Int>) = sourceHeader
            .pointee.splitRangeIndices(inRange: preMappedSourceRange)

        assert(
            sourceSplitRange.low.startIndex >= 0
                && (sourceSplitRange.low.startIndex < sourceHeader.pointee.capacity
                    || sourceSplitRange.low.startIndex == sourceSplitRange.low.endIndex)
        )
        assert(
            sourceSplitRange.low.endIndex >= 0
                && sourceSplitRange.low.endIndex <= sourceHeader.pointee.capacity)

        assert(
            sourceSplitRange.high.startIndex >= 0
                && (sourceSplitRange.high.startIndex < sourceHeader.pointee.capacity
                    || sourceSplitRange.high.startIndex == sourceSplitRange.high.endIndex)
        )
        assert(
            sourceSplitRange.high.endIndex >= 0
                && sourceSplitRange.high.endIndex <= sourceHeader.pointee.capacity)

        destinationBody.advanced(by: postMappedDestinationRange.startIndex).initialize(
            from: sourceBody.advanced(by: sourceSplitRange.low.startIndex),
            count: sourceSplitRange.low.count)
        destinationBody.advanced(
            by: postMappedDestinationRange.startIndex + sourceSplitRange.low.count
        ).initialize(
            from: sourceBody.advanced(by: sourceSplitRange.high.startIndex),
            count: sourceSplitRange.high.count)
    }

    // Internal implementation of replaceSubrange<C>(_:with:) when no reallocation
    // of the underlying buffer is required
    private static func mutateWithoutReallocate<C>(
        info: DequeMutationInfo2, elements newElements: C,
        header: UnsafeMutablePointer<DequeHeader>, body: UnsafeMutablePointer<T>
    ) where C: Collection, C.Iterator.Element == T {
        if info.removed > 0 {
            Deque.deinitialize(
                range: info.start..<(info.start + info.removed), header: header, body: body)
        }

        if info.removed != info.inserted {
            if info.start < header.pointee.count - (info.start + info.removed) {
                let oldOffset: Int = header.pointee.offset
                header.pointee.offset -= info.inserted - info.removed
                if header.pointee.offset < 0 {
                    header.pointee.offset += header.pointee.capacity
                } else if header.pointee.offset >= header.pointee.capacity {
                    header.pointee.offset -= header.pointee.capacity
                }
                let delta: Int = oldOffset - header.pointee.offset
                if info.start != 0 {
                    let destinationSplitIndices:
                        (low: CountableRange<Int>, high: CountableRange<Int>) = header.pointee
                            .splitRangeIndices(
                                inRange: 0..<info.start)
                    let lowCount: Int = destinationSplitIndices.low.count
                    Deque.moveInitialize(
                        preMappedSourceRange: delta..<(delta + lowCount),
                        postMappedDestinationRange: destinationSplitIndices.low,
                        sourceHeader: header, sourceBody: body, destinationBody: body)
                    if lowCount != info.start {
                        Deque.moveInitialize(
                            preMappedSourceRange: (delta + lowCount)..<(info.start + delta),
                            postMappedDestinationRange: destinationSplitIndices.high,
                            sourceHeader: header, sourceBody: body, destinationBody: body)
                    }
                }
            } else {
                if (info.start + info.removed) != header.pointee.count {
                    let start: Int = info.start + info.removed
                    let end: Int = header.pointee.count
                    let destinationSplitIndices:
                        (low: CountableRange<Int>, high: CountableRange<Int>) = header.pointee
                            .splitRangeIndices(
                                inRange: (info.start + info.inserted)..<(end - info.removed
                                    + info.inserted)
                            )
                    let lowCount: Int = destinationSplitIndices.low.count

                    Deque.moveInitialize(
                        preMappedSourceRange: start..<end,
                        postMappedDestinationRange: destinationSplitIndices.low,
                        sourceHeader: header, sourceBody: body, destinationBody: body)
                    if lowCount != end - start {
                        Deque.moveInitialize(
                            preMappedSourceRange: (start + lowCount)..<end,
                            postMappedDestinationRange: destinationSplitIndices.high,
                            sourceHeader: header, sourceBody: body, destinationBody: body)
                    }
                }
            }
            header.pointee.count = header.pointee.count - info.removed + info.inserted
        }

        if info.inserted == 1, let e: T = newElements.first {
            if info.start >= header.pointee.capacity - header.pointee.offset {
                body.advanced(by: info.start - header.pointee.capacity + header.pointee.offset)
                    .initialize(to: e)
            } else {
                body.advanced(by: header.pointee.offset + info.start).initialize(to: e)
            }
        } else if info.inserted > 0 {
            let inserted: (low: CountableRange<Int>, high: CountableRange<Int>) = header.pointee
                .splitRangeIndices(
                    inRange: info.start..<(info.start + info.inserted))
            var iterator: C.Iterator = newElements.makeIterator()
            for i in inserted.low {
                if let n: T = iterator.next() {
                    body.advanced(by: i).initialize(to: n)
                }
            }
            for i in inserted.high {
                if let n: T = iterator.next() {
                    body.advanced(by: i).initialize(to: n)
                }
            }
        }
    }

    // Internal implementation of replaceSubrange<C>(_:with:) when reallocation
    // of the underlying buffer is required. Can handle no previous buffer or
    // previous buffer too small or previous buffer too big or previous buffer
    // non-unique.
    private mutating func reallocateAndMutate<C>(
        info: DequeMutationInfo2, elements newElements: C,
        header: UnsafeMutablePointer<DequeHeader>?, body: UnsafeMutablePointer<T>?,
        deletePrevious: Bool
    ) where C: Collection, C.Iterator.Element == T {
        if info.newCount == 0 {
            // Let the regular deallocation handle the deinitialize
            buffer = nil
        } else {
            let newCapacity: Int
            let oldCapacity: Int = header?.pointee.capacity ?? 0
            if info.newCount > oldCapacity || info.newCount <= oldCapacity / downsizeTriggerFactor {
                newCapacity = Swift.max(minCapacity, info.newCount * overAllocateFactor)
            } else {
                newCapacity = oldCapacity
            }

            let newBuffer: DequeBuffer<T> =
                DequeBuffer<T>.create(minimumCapacity: newCapacity) {
                    (buffer: ManagedBuffer<DequeHeader, T>) in
                    return DequeHeader(offset: 0, count: info.newCount, capacity: newCapacity)
                } as! DequeBuffer<T>
            if let headerPtr: UnsafeMutablePointer<DequeHeader> = header,
                let bodyPtr: UnsafeMutablePointer<T> = body
            {
                if deletePrevious, info.removed > 0 {
                    Deque.deinitialize(
                        range: info.start..<(info.start + info.removed), header: headerPtr,
                        body: bodyPtr)
                }

                newBuffer.withUnsafeMutablePointerToElements { (newBody: UnsafeMutablePointer<T>) in
                    if info.start != 0 {
                        if deletePrevious {
                            Deque.moveInitialize(
                                preMappedSourceRange: 0..<info.start,
                                postMappedDestinationRange: 0..<info.start, sourceHeader: headerPtr,
                                sourceBody: bodyPtr, destinationBody: newBody)
                        } else {
                            Deque.copyInitialize(
                                preMappedSourceRange: 0..<info.start,
                                postMappedDestinationRange: 0..<info.start, sourceHeader: headerPtr,
                                sourceBody: bodyPtr, destinationBody: newBody)
                        }
                    }

                    let oldCount: Int = header?.pointee.count ?? 0
                    if info.start + info.removed != oldCount {
                        if deletePrevious {
                            Deque.moveInitialize(
                                preMappedSourceRange: (info.start + info.removed)..<oldCount,
                                postMappedDestinationRange: (info.start + info.inserted)..<info
                                    .newCount, sourceHeader: headerPtr, sourceBody: bodyPtr,
                                destinationBody: newBody)
                        } else {
                            Deque.copyInitialize(
                                preMappedSourceRange: (info.start + info.removed)..<oldCount,
                                postMappedDestinationRange: (info.start + info.inserted)..<info
                                    .newCount, sourceHeader: headerPtr, sourceBody: bodyPtr,
                                destinationBody: newBody)
                        }
                    }
                }

                // Make sure the old buffer doesn't deinitialize when it deallocates.
                if deletePrevious {
                    headerPtr.pointee.count = 0
                }
            }

            if info.inserted > 0 {
                newBuffer.withUnsafeMutablePointerToElements { (newBody: UnsafeMutablePointer<T>) in
                    let umbp: UnsafeMutableBufferPointer = UnsafeMutableBufferPointer(
                        start: newBody.advanced(by: info.start), count: info.inserted)
                    _ = umbp.initialize(from: newElements)
                }
            }

            buffer = newBuffer
        }
    }

    /// Implemetation of the RangeReplaceableCollection function. Internally
    /// implemented using either mutateWithoutReallocate or reallocateAndMutate.
    mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C: Collection, C.Iterator.Element == T {
        precondition(subrange.lowerBound >= 0, "Subrange lowerBound is negative")

        if isKnownUniquelyReferenced(&buffer), let b: DequeBuffer<T> = buffer {
            b.withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>) in
                let info: DequeMutationInfo2 = DequeMutationInfo2(
                    subrange: subrange, previousCount: headerPtr.pointee.count,
                    insertedCount: numericCast(newElements.count))
                if info.newCount <= headerPtr.pointee.capacity
                    && (info.newCount < minCapacity
                        || info.newCount > headerPtr.pointee.capacity / downsizeTriggerFactor)
                {
                    Deque.mutateWithoutReallocate(
                        info: info, elements: newElements, header: headerPtr, body: bodyPtr)
                } else {
                    reallocateAndMutate(
                        info: info, elements: newElements, header: headerPtr, body: bodyPtr,
                        deletePrevious: true)
                }
            }
        } else if let b: DequeBuffer<T> = buffer {
            b.withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>) in
                let info: DequeMutationInfo2 = DequeMutationInfo2(
                    subrange: subrange, previousCount: headerPtr.pointee.count,
                    insertedCount: numericCast(newElements.count))
                reallocateAndMutate(
                    info: info, elements: newElements, header: headerPtr, body: bodyPtr,
                    deletePrevious: false)
            }
        } else {
            let info: DequeMutationInfo2 = DequeMutationInfo2(
                subrange: subrange, previousCount: 0, insertedCount: numericCast(newElements.count))
            reallocateAndMutate(
                info: info, elements: newElements, header: nil, body: nil, deletePrevious: true)
        }
    }
}

// Internal state for the Deque
private struct DequeHeader {
    var offset: Int
    var count: Int
    var capacity: Int

    // Translate from preMapped to postMapped indices.
    //
    // "preMapped" refer to the indices exposed by this type (zero based, contiguous), and "postMapped" refers to internal offsets within the buffer (not necessarily zero based and may wrap around).
    //
    // Since "postMapped" indices are not necessarily contiguous, two separate, contiguous ranges are returned. Both `startIndex` and `endIndex` in the `high` range will equal the `endIndex` in the `low` range if the range specified by `inRange` is continuous after mapping.
    func splitRangeIndices(inRange: CountableRange<Int>) -> (
        low: CountableRange<Int>, high: CountableRange<Int>
    ) {
        let limit: Int = capacity - offset
        if inRange.startIndex >= limit {
            return (
                low: (inRange.startIndex - limit)..<(inRange.endIndex - limit),
                high: (inRange.endIndex - limit)..<(inRange.endIndex - limit)
            )
        } else if inRange.endIndex > limit {
            return (
                low: (inRange.startIndex + offset)..<capacity, high: 0..<(inRange.endIndex - limit)
            )
        }
        return (
            low: (inRange.startIndex + offset)..<(inRange.endIndex + offset),
            high: (inRange.endIndex + offset)..<(inRange.endIndex + offset)
        )
    }

}

// Private type used to communicate parameters between replaceSubrange<C>(_:with:)
// and reallocateAndMutate or mutateWithoutReallocate
private struct DequeMutationInfo2 {
    let start: Int
    let removed: Int
    let inserted: Int
    let newCount: Int

    init(subrange: Range<Int>, previousCount: Int, insertedCount: Int) {
        precondition(subrange.upperBound <= previousCount, "Subrange upperBound is out of range")

        self.start = subrange.lowerBound
        self.removed = subrange.count
        self.inserted = insertedCount
        self.newCount = previousCount - self.removed + self.inserted
    }
}

// Private reimplementation of function with same name from stdlib/public/core/BuiltIn.swift
private func roundUp(_ offset: UInt, toAlignment alignment: Int) -> UInt {
    let x: UInt = offset + UInt(bitPattern: alignment) &- 1
    return x & ~(UInt(bitPattern: alignment) &- 1)
}

// Private reimplementation of definition from stdlib/public/SwiftShims/HeapObject.h
private struct HeapObject {
    let metadata: Int = 0
    let strongRefCount: UInt32 = 0
    let weakRefCount: UInt32 = 0
}

// An implementation of DequeBuffer using ManagedBufferPointer to allocate the
// storage and then using raw pointer offsets into self to access contents
// (avoiding the ManagedBufferPointer accessors which are a performance problem
// in Swift 3).
private final class DequeBuffer<T>: ManagedBuffer<DequeHeader, T> {
    private static var headerOffset: Int {
        return Int(
            roundUp(
                UInt(MemoryLayout<HeapObject>.size),
                toAlignment: MemoryLayout<DequeHeader>.alignment))
    }

    private static var elementOffset: Int {
        return Int(
            roundUp(
                UInt(headerOffset) + UInt(MemoryLayout<DequeHeader>.size),
                toAlignment: MemoryLayout<T>.alignment))
    }

    private var bodyPtr: UnsafeMutablePointer<T> {
        return Unmanaged<DequeBuffer<T>>.passUnretained(self).toOpaque().advanced(
            by: DequeBuffer<T>.elementOffset
        ).assumingMemoryBound(to: T.self)
    }

    private var headerPtr: UnsafeMutablePointer<DequeHeader> {
        return Unmanaged<DequeBuffer<T>>.passUnretained(self).toOpaque().advanced(
            by: DequeBuffer<T>.headerOffset
        ).assumingMemoryBound(to: DequeHeader.self)
    }

    deinit {
        #if true
            // We need to assert this in case some of our dirty assumptions stop being true
            assert(
                ManagedBufferPointer<DequeHeader, T>(unsafeBufferObject: self)
                    .withUnsafeMutablePointers {
                        (header: UnsafeMutablePointer<DequeHeader>, body: UnsafeMutablePointer<T>)
                        in
                        self.headerPtr == header && self.bodyPtr == body
                    })

            let splitRange: (low: CountableRange<Int>, high: CountableRange<Int>) = headerPtr
                .pointee.splitRangeIndices(inRange: 0..<headerPtr.pointee.count)
            bodyPtr.advanced(by: splitRange.low.startIndex).deinitialize(
                count: splitRange.low.count)
            bodyPtr.advanced(by: splitRange.high.startIndex).deinitialize(
                count: splitRange.high.count)
        #else
            withUnsafeMutablePointers {
                (headerPtr: UnsafeMutablePointer<DequeHeader>, bodyPtr: UnsafeMutablePointer<T>) in
                let splitRange: (low: CountableRange<Int>, high: CountableRange<Int>) = headerPtr
                    .pointee.splitRangeIndices(inRange: 0..<headerPtr.pointee.count)
                bodyPtr.advanced(by: splitRange.low.startIndex).deinitialize(
                    count: splitRange.low.count)
                bodyPtr.advanced(by: splitRange.high.startIndex).deinitialize(
                    count: splitRange.high.count)
            }
        #endif
    }
}
