//
//  IndexedObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-08-15.
//

import Foundation
import RxSwift

class Index<T> {
    var value: Int
    var list: LazyCollection<[T]>
    private weak var internalPrevious: BehaviorSubject<Int>?
    private weak var internalNext: BehaviorSubject<Int>?
    
    public var previous: Observable<T?> {
        let previous = internalPrevious ?? BehaviorSubject<Int>(value: value - 1)
        
        internalPrevious = previous
        
        return previous.map { [previous] previousIndex -> T? in
            guard previousIndex >= 0 else {
                return nil
            }
            
            return self.list[previousIndex]
        }
    }
    
    public var next: Observable<T?> {
        let next = internalNext ?? BehaviorSubject<Int>(value: value + 1)
        
        internalNext = next
        
        return next.map { [next] nextIndex -> T? in
            guard nextIndex < self.list.count else {
                return nil
            }
            
            return self.list[nextIndex]
        }
    }
    
    init(value: Int, list: LazyCollection<[T]>) {
        self.value = value
        self.list = list
    }
    
    func postUpdate(list: LazyCollection<[T]>) {
        self.list = list
        
        let previous = internalPrevious
        let next = internalNext
        let centerIndex = value
        
        if previous != nil {
            previous?.onNext(centerIndex - 1)
        } else {
            preconditionFailure(String(format: "wtfprevious %d", centerIndex))
        }
        
        if next != nil {
            next?.onNext(centerIndex + 1)
        } else {
            preconditionFailure(String(format: "wtfnext %d", centerIndex))
        }
    }
}

class UpdateHolder<T>: NSObject {
    var indices: [Index<T>]
    let update: Update<T>?
    
    func get(_ index: Int, create: Bool = true) -> Index<T>? {
        guard let existingIndex = indices.first(where: { lookupIndex in
            lookupIndex.value == index
        }) else {
            if create {
                guard let update = update else {
                    preconditionFailure("Attempt to create index with no update")
                }
                
                let index = Index<T>(value: index, list: update.list)
                
                indices.append(index)
                
                return index
            } else {
                return nil
            }
        }
        
        return existingIndex
    }
    
    func adjustIndices(start: Int, end: Int, adjustment: Int) {
        (start...end)
            .map { offset -> Index<T>? in
                guard let existingIndex = get(offset, create: false) else {
                    return nil
                }
                
                return existingIndex
            }
            .forEach { index in
                index?.value += adjustment
            }
    }
    
    func reset() {
        indices.removeAll()
    }
    
    override convenience init() {
        self.init(indices: [], update: nil)
    }
    
    init(indices: [Index<T>], update: Update<T>?) {
        self.indices = indices
        self.update = update
        
        super.init()
    }
}

private class IndexedObservableList<T, U>: ObservableList<U> {
    private let list: ObservableList<T>
    private let transform: ((T, Observable<T?>, Observable<T?>) -> U)
    
    init(_ list: ObservableList<T>, transform: @escaping ((T, Observable<T?>, Observable<T?>) -> U)) {
        self.list = list
        self.transform = transform
    }
    
    public override var updates: Observable<Update<U>> {
        let transform = self.transform
        
        return list.updates
            .scan(UpdateHolder<T>()) { (holder, update) -> UpdateHolder<T> in
                let listSize = update.list.count
                
                update.changes.forEach { change in
                    switch change {
                    case .insert(let index):
                        holder.adjustIndices(start: index, end: listSize - 1, adjustment: 1)
                    case .delete(let index):
                        holder.adjustIndices(start: index, end: listSize, adjustment: -1)
                    case .move(let from, let to):
                        if to < from {
                            holder.adjustIndices(start: to, end: from, adjustment: 1)
                        } else {
                            holder.adjustIndices(start: from + 1, end: to, adjustment: -1)
                        }
                    case .reload:
                        holder.reset()
                    }
                }
                
                holder.indices.forEach { index in
                    index.postUpdate(list: update.list)
                }
                
                return UpdateHolder(indices: holder.indices, update: update)
            }
            .map { holder in
                guard let update = holder.update else {
                    preconditionFailure("Update must always be present")
                }
                
                let placeholderList = 0 ..< update.list.count
                
                return Update(list: placeholderList.lazy.map({ index in
                    let value = update.list[index]
                    
                    guard let indexWrapper = holder.get(index) else {
                        preconditionFailure("Index must always be created")
                    }
                    
                    return transform(value, indexWrapper.previous, indexWrapper.next)
                }), changes: update.changes)
            }
    }
}

public extension ObservableList {
    
    func indexedMap<U>(_ transform: @escaping ((T, Observable<T?>, Observable<T?>) -> U)) -> ObservableList<U> {
        return IndexedObservableList<T, U>(self, transform: transform)
    }
}
