//
//  SingletonObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

fileprivate class SingletonObservableList<T>: ObservableList<T> {
    private let values: [T]
    
    init(_ values: [T]) {
        self.values = values
    }
    
    override var updates: Observable<Update<T>> {
        get {
            return Observable.just(Update(list: values, changes: [Change.reload]))
        }
    }
}

public extension ObservableList {
    static func of<T>(_ values: T...) -> ObservableList<T> {
        return SingletonObservableList(values)
    }
    
    static func of<T>(_ values: [T]) -> ObservableList<T> {
        return SingletonObservableList(values)
    }
}
