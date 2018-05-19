//
//  SubjectMap.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift

class SubjectMap<KeyType: AnyObject, ValueType: AnyObject>: NSObject {
    
    private let sources: NSMapTable<KeyType, ReplaySubject<ValueType>> = NSMapTable(keyOptions: NSPointerFunctions.Options.strongMemory,
                                                                                    valueOptions: NSPointerFunctions.Options.strongMemory)
    
    private func source(forKey key: KeyType) -> ReplaySubject<ValueType> {
        guard let cachedSource = sources.object(forKey: key) else {
            let createdSource = ReplaySubject<ValueType>.create(bufferSize: 1)
            
            sources.setObject(createdSource, forKey: key)
            
            return createdSource
        }
        
        return cachedSource
    }
    
    private func emitUpdate(key: KeyType, consumer: ((ReplaySubject<ValueType>) -> Void)) {
        source(forKey: key).on(Event<ValueType>.completed)
    }
    
    public func on(key: KeyType, _ generator: (() -> Event<ValueType>) ) {
        emitUpdate(key: key) { subject in
            subject.on(generator())
        }
    }
    
    public func on(key: KeyType, _ event: Event<ValueType>) {
        emitUpdate(key: key) { (subject) in
            subject.on(event)
        }
    }

    func get(key: KeyType) -> Observable<ValueType> {
        return source(forKey: key)
    }
}

extension SubjectMap {
    
    public func onNext(key: KeyType, _ generator: (() -> ValueType)) {
        on(key: key) {
            .next(generator())
        }
    }
    
    public func onNext(key: KeyType, _ element: ValueType) {
        on(key: key, .next(element))
    }
    
    public func onCompleted(key: KeyType) {
        on(key: key, .completed)
    }
    
    public func onError(key: KeyType, _ error: Swift.Error) {
        on(key: key, .error(error))
    }
}
