//
//  MappedObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

fileprivate class MappedObservableList<T, U>: ObservableList<U> {
    private let list: ObservableList<T>
    private let transform: ((T) -> U)
    
    init(_ list: ObservableList<T>, transform: @escaping ((T) -> U)) {
        self.list = list
        self.transform = transform
    }
    
    public override var updates: Observable<Update<U>> {
        get {
            let transform = self.transform
            
            return list.updates
                .map { Update(list: $0.list.lazy.map(transform), changes: $0.changes) }
        }
    }
}

public extension ObservableList {
    func map<U>(_ transform: @escaping ((T) -> U)) -> ObservableList<U> {
        return MappedObservableList<T, U>(self, transform: transform)
    }
}
