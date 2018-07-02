//
//  DifferentialObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift
import DeepDiff

private class DifferentialObservableList<T: Hashable>: ObservableList<T> {
    private let stream: Observable<[T]>
    
    init(_ stream: Observable<[T]>) {
        self.stream = stream
    }
    
    override var updates: Observable<Update<T>> {
        return stream
            .map { (list: [T]) -> Update<T> in
                return Update<T>(list: list, changes: [.reload])
            }
            .scan(Update(list: [], changes: [])) { (previous, next) -> Update<T> in
                if previous.changes.isEmpty {
                    return Update(list: next.list, changes: [.reload])
                }
                
                return Update(list: next.list, changes: DeepDiff.diff(old: previous.list.elements, new: next.list.elements)
                    .map { (change) -> Change in
                        switch change {
                        case .insert(let insert):
                            return .insert(index: insert.index)
                        case .delete(let delete):
                            return .delete(index: delete.index)
                        case .move(let move):
                            return .move(from: move.fromIndex, to: move.toIndex)
                        case .replace(let replace):
                            return .move(from: replace.index, to: replace.index)
                        }
                })
        }
    }
}

public extension ObservableList {
    static func diff<T: Hashable>(_ values: Observable<[T]>) -> ObservableList<T> {
        return DifferentialObservableList(values)
    }
}
