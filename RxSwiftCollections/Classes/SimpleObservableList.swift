//
//  SimpleObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

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
    func append(_ element: T) {
        update { previous -> Update<T> in
            var next = Array(previous)
            
            next.append(element)
            
            return Update(list: next, changes: [.insert(index: next.count - 1)])
        }
    }
    
    func insert(_ element: T, at: Int) {
        update { previous -> Update<T> in
            var next = Array(previous)
            
            next.insert(element, at: at)
            
            return Update(list: next, changes: [.insert(index: at)])
        }
    }
    
    func remove(at: Int) {
        update { previous -> Update<T> in
            var next = Array(previous)
            
            next.remove(at: at)
            
            return Update(list: next, changes: [.delete(index: at)])
        }
    }
    
    func removeAll() {
        update { previous -> Update<T> in
            return Update(list: [], changes: [.reload])
        }
    }
}
