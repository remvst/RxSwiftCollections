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
    
    override var updates: Observable<Update<U>> {
        get {
            return list.updates
                .map { [weak self] in
                    return Update(list: $0.list.lazy.map(self!.transform), changes: $0.changes)
            }
        }
    }
}

public extension ObservableList {
    func map<U>(_ transform: @escaping ((T) -> U)) -> ObservableList<U> {
        return MappedObservableList<T, U>(self, transform: transform)
    }
}
