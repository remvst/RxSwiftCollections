//
//  ObservableListBinding.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import RxSwift

fileprivate class ObservableListDataSource<T>: NSObject, UICollectionViewDataSource {
    
    private var currentList: LazyCollection<[T]>?
    private let observableList: Observable<Update<T>>
    private let cellCreator: ((UICollectionView, IndexPath, T) -> UICollectionViewCell)
    
    var disposable: Disposable!
    
    init(list: Observable<Update<T>>, cellCreator: @escaping ((UICollectionView, IndexPath, T) -> UICollectionViewCell)) {
        self.observableList = list
        self.cellCreator = cellCreator
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.currentList?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = self.currentList![indexPath.item]
        
        return cellCreator(collectionView, indexPath, item)
    }
    
    func bind(to collectionView: UICollectionView) -> Disposable {
        return self.observableList
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (update) in
                guard let this = self else {
                    return
                }
                
                guard update.changes.first(where: { (change) -> Bool in
                    if case .reload = change {
                        return true
                    }
                    
                    return false
                }) == nil else {
                    this.currentList = update.list
                    collectionView.reloadData()
                    
                    return
                }
                
                collectionView.performBatchUpdates({
                    this.currentList = update.list
                    
                    update.changes.forEach({ (change) in
                        switch (change) {
                        case .insert(let index):
                            collectionView.insertItems(at: [IndexPath(item: index, section: 0)])
                            break
                        case .delete(let index):
                            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
                            break
                        case .move(let from, let to):
                            collectionView.moveItem(at: IndexPath(item: from, section: 0), to: IndexPath(item: to, section: 0))
                            break
                        case .reload:
                            break
                        }
                    })
                }, completion: { complete in })
            }, onError: { (error) in
            }, onCompleted: {
            }) {
        }
    }
}

fileprivate class AssociatedObjectDisposable: Disposable {
    var retained: AnyObject!
    let disposable: Disposable
    
    init (retaining retained: AnyObject, disposing disposable: Disposable) {
        self.retained = retained
        self.disposable = disposable
    }
    
    func dispose() {
        self.retained = nil
        self.disposable.dispose()
    }
}

public extension Observable {
    
    func bind<CellType: UICollectionViewCell, T: Hashable>(to collectionView: UICollectionView,
                                                           reusing reuseIdentifier: String,
                                                           with adapter: @escaping ((CellType, T) -> CellType)) -> Disposable where E == [T] {
        return ObservableList<T>.diff(self)
            .bind(to: collectionView, reusing: reuseIdentifier, with: adapter)
    }
}

public extension ObservableList {
    
    func bind<CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                              reusing reuseIdentifier: String,
                                              with adapter: @escaping ((CellType, T) -> CellType)) -> Disposable {
        return bind(to: collectionView,
                    reusing: reuseIdentifier,
                    with: { cell, indexPath, value -> CellType in return adapter(cell, value) })
    }
    
    func bind<CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                              reusing reuseIdentifier: String,
                                              with adapter: @escaping ((CellType, IndexPath, T) -> CellType)) -> Disposable {
        return bind(to: collectionView,
                    with: { collectionView, indexPath, value -> CellType in
                        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! CellType
                        
                        return adapter(cell, indexPath, value)
        })
    }
    
    func bind<CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                              with adapter: @escaping ((UICollectionView, IndexPath, T) -> CellType)) -> Disposable {
        let dataSource = ObservableListDataSource(list: self.updates, cellCreator: adapter)
        let disposable = dataSource.bind(to: collectionView)
        
        collectionView.dataSource = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}
