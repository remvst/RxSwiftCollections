//
//  ObservableListBinding.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import RxSwift

fileprivate class ObservableListDataSource<T>: NSObject, UICollectionViewDataSource {
    
    private var currentList: [T]?
    private let observableList: ObservableList<T>
    private let cellCreator: ((UICollectionView, IndexPath, T) -> UICollectionViewCell)
    
    var disposable: Disposable!
    
    init(list: ObservableList<T>, cellCreator: @escaping ((UICollectionView, IndexPath, T) -> UICollectionViewCell)) {
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
        return cellCreator(collectionView, indexPath, self.currentList![indexPath.item])
    }
    
    func bind(to collectionView: UICollectionView) -> Disposable {
        return self.observableList.updates
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (update) in
                self!.currentList = update.list
                
                collectionView.performBatchUpdates({
                    update.changes.forEach({ (change) in
                        switch (change) {
                        case Change.insert(let index):
                            collectionView.insertItems(at: [IndexPath(index: index)])
                            break
                        case Change.delete(let index):
                            collectionView.deleteItems(at: [IndexPath(index: index)])
                            break
                        case Change.move(let from, let to):
                            collectionView.moveItem(at: IndexPath(index: from), to: IndexPath(index: to))
                            break
                        case Change.reload:
                            collectionView.reloadData()
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
        let dataSource = ObservableListDataSource(list: self, cellCreator: adapter)
        let disposable = dataSource.bind(to: collectionView)
        
        collectionView.dataSource = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}
