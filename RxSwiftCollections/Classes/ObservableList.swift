//
//  ObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

/// Another useful function
/// - parameters:
///   - alpha: Describe the alpha param
///   - beta: Describe the beta param

public enum Change {
    /// Represents the insertion of a new item in the list
    /// - parameters:
    ///   - index: The position at which a new item was inserted
    case insert(index: Int)
    
    /// Represents the deletion of an item from the list
    /// - parameters:
    ///   - index: The position at which the deletion occurred
    case delete(index: Int)
    
    /// Represents a move of an element from a source position to
    /// the destination
    /// - parameters:
    ///   - from: The original index of the item in the list
    ///   - to: The target index within the list
    case move(from: Int, to: Int)
    
    /// The complete, underlying list should be reloaded
    case reload
}

/// Represents an instantaneous, immutable update to an underlying
/// observable list. The list contained within the update is the result
/// of applying the set of included changes to the previous list. The
/// list is a complete, immutable copy of all data present in the underlying
/// list at the instant this update was emitted
public class Update<T> {
    public var list: LazyCollection<[T]>
    public var changes: [Change]
    
    init(list: [T], changes: [Change]) {
        self.list = list.lazy
        self.changes = changes
    }
    
    init(list: LazyCollection<[T]>, changes: [Change]) {
        self.list = list
        self.changes = changes
    }
}

/// Represents an a reactive stream of changes to an underlying list. The
/// changes to the list are emitted from the updates observable associated
/// with this list
public class ObservableList<T> {
    
    /// The stream of updates to the underlying reactive list
    public var updates: Observable<Update<T>> {
        get {
            assertionFailure("Don't call me directly")
            
            return Observable.just(Update(list: [], changes: []))
        }
    }
}
