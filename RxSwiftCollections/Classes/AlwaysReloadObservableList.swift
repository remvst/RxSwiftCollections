//
//  AlwaysReloadObservableList.swift
//  DeepDiff
//
//  Created by Rémi Vansteelandt on 11/09/2018.
//

import Foundation
import RxSwift

// Naive ObservableList that will fire a reload update for every onNext event in the source stream
private class AlwaysReloadObservableList: ObservableList {
    
    private let stream: Observable<[T]>
    
    init(_ stream: Observable<[T]>) {
        self.stream = stream
        super.init()
    }
    
    override var updates: Observable<Update<T>> {
        return stream.map({ Update(list: $0, changes: [Change.reload]) })
    }
    
}

public extension ObservableList {
    static func alwaysReload<T>(_ values: Observable<[T]>) -> ObservableList<T> {
        return AlwaysReloadObservableList(values)
    }
}
