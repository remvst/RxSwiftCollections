//
//  IndexedObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-08-15.
//

import Foundation
import RxSwift

class Index<T> {
    let value: Int
    private weak var internalPrevious: PublishSubject<T?>?
    private weak var internalNext: PublishSubject<T?>?
    
    public var previous: PublishSubject<T?> {
        get {
            let previous = internalPrevious ?? PublishSubject<T?>()
            
            internalPrevious = previous
            
            return previous
        }
    }
    
    public var next: PublishSubject<T?> {
        get {
            let next = internalNext ?? PublishSubject<T?>()
            
            internalNext = next
            
            return next
        }
    }
    
    init(value: Int) {
        self.value = value
    }
}

class Indices<T>: NSObject {
    private var indices: [Index<T>]
    
    override init() {
        self.indices = []
    }
    
    func get(_ index: Int) -> Index<T> {
        return Index<T>(value: index)
    }
}

class UpdateHolder<T>: NSObject {
    let indices: Indices<T>
    let update: Update<T>?
    
    override convenience init() {
        self.init(indices: Indices<T>(), update: nil)
    }
    
    init(indices: Indices<T>, update: Update<T>?) {
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
                return UpdateHolder(indices: holder.indices, update: update)
            }
            .map { holder in
                let placeholderList = 0..<holder.update!.list.count
                
                return Update(list: placeholderList.lazy.map({ index in
                    let value = holder.update!.list[index]
                    let indexWrapper = holder.indices.get(index)
                    
                    return transform(value, indexWrapper.previous, indexWrapper.next)
                }), changes: holder.update!.changes)
            }
    }
}

public extension ObservableList {
    
    func indexedMap<U>(_ transform: @escaping ((T, Observable<T?>, Observable<T?>) -> U)) -> ObservableList<U> {
        return IndexedObservableList<T, U>(self, transform: transform)
    }
}
