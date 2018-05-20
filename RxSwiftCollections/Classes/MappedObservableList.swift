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
    
    /// Returns a new `ObservableList` which maps each emitted update in
    /// the list by applying the supplied closure to the underlying elements
    /// - parameters:
    ///   - transform: A mapping closure. `transform` accepts an
    ///     element within the list at the time of the latest update  as its
    ///     parameter and returns a transformed value
    /// - Returns: An observable list which will emit mapped values whenever
    ///   the underlying list updates
    func map<U>(_ transform: @escaping ((T) -> U)) -> ObservableList<U> {
        return MappedObservableList<T, U>(self, transform: transform)
    }
}
