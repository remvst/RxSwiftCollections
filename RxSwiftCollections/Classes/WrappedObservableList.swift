//
//  WrappedObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-20.
//

import Foundation
import RxSwift

fileprivate class WrappedObservableList<T>: ObservableList<T> {
    private let wrappedUpdates: Observable<Update<T>>
    
    init(_ updates: Observable<Update<T>>) {
        self.wrappedUpdates = updates
    }
    
    override var updates: Observable<Update<T>> {
        get {
            return wrappedUpdates
        }
    }
}

public extension ObservableList {
    public func subscribeOn(_ scheduler: ImmediateSchedulerType) -> ObservableList<T> {
        return WrappedObservableList(self.updates.subscribeOn(scheduler))
    }
    
    public func observeOn(_ scheduler: ImmediateSchedulerType) -> ObservableList<T> {
        return WrappedObservableList(self.updates.observeOn(scheduler))
    }
}
