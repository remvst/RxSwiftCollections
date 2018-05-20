//
//  ObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

public enum Change {
    case insert(index: Int)
    case delete(index: Int)
    case move(from: Int, to: Int)
    case reload
}

public class Update<T> {
    public var list: [T]
    public var changes: [Change]
    
    init(list: [T], changes: [Change]) {
        self.list = list
        self.changes = changes
    }
}

public class ObservableList<T> {
    public var updates: Observable<Update<T>> {
        get {
            assertionFailure("Don't call me directly")
            
            return Observable.just(Update(list: [], changes: []))
        }
    }
}
