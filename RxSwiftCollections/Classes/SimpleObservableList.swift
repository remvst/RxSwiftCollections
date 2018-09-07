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
//    private var updateQueue = [Update<T>]()
    private let subject: PublishSubject<Update<T>> = PublishSubject()
    
    private let queue = DispatchQueue(label: "SimpleObservableListQueue")
    
    public override init() {
    }
    
    public init(_ values: [T]) {
        self.currentList = values
    }
    
    public init(_ values: T...) {
        self.currentList = values
    }
    
    private func update(_ updater: @escaping (([T]) -> Update<T>)) {
        guard let update = queue.sync(execute: { () -> Update<T>? in
            let listCopy = Array(self.currentList ?? [])
            let update = updater(listCopy)
            
            self.currentList = update.list.elements
            
            return update
        }) else {
            return
        }
        
        self.subject.onNext(update)
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
    
    func appendAll(_ elements: [T]) {
        update { previous -> Update<T> in
            var next = Array(previous)
            next.append(contentsOf: elements)
            
            var changes = [Change]()
            
            for i in 0 ..< elements.count {
                changes.append(.insert(index: previous.count + i))
            }
            
            return Update(list: next, changes: changes)
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
        update { _ -> Update<T> in
            return Update(list: [], changes: [.reload])
        }
    }
}
