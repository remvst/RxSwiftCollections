//
//  IndexedObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-08-15.
//

import Foundation
import RxSwift

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
            .map { Update(list: $0.list.lazy.map({ value in
                transform(value, Observable.empty(), Observable.empty())
            }), changes: $0.changes) }
    }
}

public extension ObservableList {
    
    func indexedMap<U>(_ transform: @escaping ((T, Observable<T?>, Observable<T?>) -> U)) -> ObservableList<U> {
        return IndexedObservableList<T, U>(self, transform: transform)
    }
}
