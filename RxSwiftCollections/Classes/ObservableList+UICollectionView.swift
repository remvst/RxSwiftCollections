//
//  ObservableListBinding.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import RxSwift

private class ObservableListDataSource<T>: NSObject, UICollectionViewDataSource {
    
    fileprivate var currentList: LazyCollection<[T]>?
    fileprivate let observableList: Observable<Update<T>>
    fileprivate let cellCreator: ((UICollectionView, IndexPath, T) -> UICollectionViewCell)
    
    fileprivate var disposable: Disposable!
    
    init(list: Observable<Update<T>>,
         cellCreator: @escaping ((UICollectionView, IndexPath, T) -> UICollectionViewCell)) {
        self.observableList = list
        self.cellCreator = cellCreator
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentList?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // swiftlint:disable:next force_unwrapping
        let item = currentList![indexPath.item]

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
                    
                    update.changes.forEach { change in
                        switch change {
                        case .insert(let index):
                            collectionView.insertItems(at: [IndexPath(item: index, section: 0)])
                        case .delete(let index):
                            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
                        case .move(let from, let to):
                            collectionView.moveItem(at: IndexPath(item: from, section: 0),
                                                    to: IndexPath(item: to, section: 0))
                        case .reload:
                            break
                        }
                    }
                }, completion: { _ in })
            }, onError: { (_) in
            }, onCompleted: {
            })
    }
}

private class SizingObservableListDataSource<T>: ObservableListDataSource<T>, UICollectionViewDelegateFlowLayout {
    
    fileprivate let cellSizer: ((IndexPath, T) -> CGSize)
    
    init(list: Observable<Update<T>>,
         cellCreator: @escaping ((UICollectionView, IndexPath, T) -> UICollectionViewCell),
         cellSizer: @escaping ((IndexPath, T) -> CGSize)) {
        self.cellSizer = cellSizer
        
        super.init(list: list, cellCreator: cellCreator)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard collectionView.numberOfSections > indexPath.section else {
            return CGSize(width: 240.0, height: 240.0)
        }
        
        guard collectionView.numberOfItems(inSection: indexPath.section) > indexPath.row else {
            return CGSize(width: 240.0, height: 240.0)
        }
        
        guard currentList?.count ?? 0 > indexPath.item else {
            return CGSize(width: 240.0, height: 240.0)
        }
        
        // swiftlint:disable:next force_unwrapping
        let item = currentList![indexPath.item]
        
        return cellSizer(indexPath, item)
    }
}

// swiftlint:disable line_length

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
                    with: { cell, _, value -> CellType in return adapter(cell, value) })
    }
    
    func bind<CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                              reusing reuseIdentifier: String,
                                              with adapter: @escaping ((CellType, IndexPath, T) -> CellType),
                                              sizedBy sizer: @escaping ((IndexPath, T) -> CGSize)) -> Disposable {
        return bind(to: collectionView,
                    with: { collectionView, indexPath, value -> CellType in
                        
                        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? CellType else {
                            return CellType()
                        }
                        
                        return adapter(cell, indexPath, value)
                    },
                    sizedBy: sizer)
    }
    
    func bind<CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                              reusing reuseIdentifier: String,
                                              with adapter: @escaping ((CellType, IndexPath, T) -> CellType)) -> Disposable {
        return bind(to: collectionView,
                    with: { collectionView, indexPath, value -> CellType in
                        
                        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? CellType else {
                            return CellType()
                        }
                        
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
    
    func bind<CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                              with adapter: @escaping ((UICollectionView, IndexPath, T) -> CellType),
                                              sizedBy sizer: @escaping ((IndexPath, T) -> CGSize)) -> Disposable {
        let dataSource = SizingObservableListDataSource(list: self.updates, cellCreator: adapter, cellSizer: sizer)
        let disposable = dataSource.bind(to: collectionView)
        
        collectionView.dataSource = dataSource
        collectionView.delegate = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}

// swiftlint:enable line_length
