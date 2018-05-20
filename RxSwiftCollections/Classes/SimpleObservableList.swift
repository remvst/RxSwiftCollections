//
//  SimpleObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

/// A basic implementation of a mutable, reactive list. Standard sequence
/// operations can be used to apply changes to the list. When changes are
/// made, the list will emit updates to any listeners
public class SimpleObservableList<T>: ObservableList<T> {
    private var currentList: [T]?
    private let subject: PublishSubject<Update<T>> = PublishSubject()
    
    public override init() {
    }
    
    public init(_ values: [T]) {
        self.currentList = values
    }
    
    public init(_ values: T...) {
        self.currentList = values
    }
    
    private func update(_ updater: (([T]) -> Update<T>)) {
        let listCopy = Array(currentList ?? [])
        let update = updater(listCopy)
    
        subject.onNext(update)
        currentList = update.list
    }
    
    public override var updates: Observable<Update<T>> {
        return subject
            .startWith(Update(list: currentList ?? [], changes: [.reload]))
            .asObservable()
    }
}

public extension SimpleObservableList {
    
    /// Appends the supplied `element` to the current list
    /// - parameters:
    ///   - element: The value to be added to the underlying sequence
    func append(_ element: T) {
        update { previous -> Update<T> in
            var next = Array(previous)
            
            next.append(element)
            
            return Update(list: next, changes: [.insert(index: next.count - 1)])
        }
    }
    
    /// Inserts the supplied `element` in the current list, at the position specified
    /// - parameters:
    ///   - element: The element to be added to the underlying sequence
    ///   - at: The position at which to add `element`
    func insert(_ element: T, at: Int) {
        update { previous -> Update<T> in
            var next = Array(previous)
            
            next.insert(element, at: at)
            
            return Update(list: next, changes: [.insert(index: at)])
        }
    }
    
    /// Removes the element from the current list, at the position specified
    /// - parameters:
    ///   - at: The position at which to remove the existing element
    func remove(at: Int) {
        update { previous -> Update<T> in
            var next = Array(previous)
            
            next.remove(at: at)
            
            return Update(list: next, changes: [.delete(index: at)])
        }
    }
    
    /// Removes all elements from the current list
    func removeAll() {
        update { previous -> Update<T> in
            return Update(list: [], changes: [.reload])
        }
    }
}
