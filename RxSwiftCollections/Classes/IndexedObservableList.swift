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
    private weak var internalPrevious: PublishSubject<T?>?
    private weak var internalNext: PublishSubject<T?>?
    
    public var previous: PublishSubject<T?> {
        let previous = internalPrevious ?? PublishSubject<T?>()
        
        internalPrevious = previous
        
        return previous
    }
    
    public var next: PublishSubject<T?> {
        let next = internalNext ?? PublishSubject<T?>()
        
        internalNext = next
        
        return next
    }
    
    init(value: Int) {
        self.value = value
    }
    
    func postUpdate(_ processor: (PublishSubject<T?>?, PublishSubject<T?>?) -> Void) {
        let previous = internalPrevious
        let next = internalNext
        
        processor(previous, next)
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
                let index = Index<T>(value: index)
                
                indices.append(index)
                
                return index
            } else {
                return nil
            }
        }
        
        return existingIndex
    }
    
    func adjustIndices(start: Int, end: Int, adjustment: Int) {
        for i in start ... end {
            guard let existingIndex = get(i, create: false) else {
                continue
            }
            
            existingIndex.value += adjustment
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
                    index.postUpdate { (previous, next) in
                        let centerIndex = index.value
                        
                        if previous != nil {
                            if centerIndex == 0 {
                                previous?.onNext(nil)
                            } else {
                                previous?.onNext(update.list[centerIndex - 1])
                            }
                        }
                        
                        if next != nil {
                            if centerIndex == listSize - 1 {
                                next?.onNext(nil)
                            } else {
                                next?.onNext(update.list[centerIndex + 1])
                            }
                        }
                    }
                }
                
                return UpdateHolder(indices: holder.indices, update: update)
            }
            .map { holder in
                guard let update = holder.update else {
                    preconditionFailure("Update must always be present")
                }
                
                let placeholderList = 0..<update.list.count
                
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
