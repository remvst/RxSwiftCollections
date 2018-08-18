//
//  AssociatedObjectDisposable.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-08-17.
//

import RxSwift

class AssociatedObjectDisposable: Disposable {
    var retained: AnyObject!
    let disposable: Disposable
    
    init(retaining retained: AnyObject,
         disposing disposable: Disposable) {
        
        self.retained = retained
        self.disposable = disposable
    }
    
    func dispose() {
        retained = nil
        disposable.dispose()
    }
}
