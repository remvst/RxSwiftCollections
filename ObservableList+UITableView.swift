//
//  ObservableList+UITableView.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-07-06.
//

import RxSwift

private class ObservableListTableViewDataSource<T>: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    private var currentList: LazyCollection<[T]>?
    private let observableList: Observable<Update<T>>
    private let rowCreator: ((UITableView, IndexPath, T) -> UITableViewCell)
    
    var disposable: Disposable!
    
    init(list: Observable<Update<T>>,
         rowCreator: @escaping ((UITableView, IndexPath, T) -> UITableViewCell)) {
        self.observableList = list
        self.rowCreator = rowCreator
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentList?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable:next force_unwrapping
        let item = currentList![indexPath.item]
        
        return rowCreator(tableView, indexPath, item)
    }
    
    func bind(to tableView: UITableView) -> Disposable {
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
                    tableView.reloadData()
                    
                    return
                }
                
                tableView.beginUpdates()
                this.currentList = update.list
                
                update.changes.forEach { change in
                    switch change {
                    case .insert(let index):
                        tableView.insertRows(at: [IndexPath(item: index, section: 0)], with: UITableViewRowAnimation.automatic)
                    case .delete(let index):
                        tableView.deleteRows(at: [IndexPath(item: index, section: 0)], with: UITableViewRowAnimation.automatic)
                    case .move(let from, let to):
                        tableView.moveRow(at: IndexPath(item: from, section: 0),
                                          to: IndexPath(item: to, section: 0))
                    case .reload:
                        break
                    }
                }
                tableView.endUpdates()
            }, onError: { (_) in
            }, onCompleted: {
            })
    }
}

private class AssociatedObjectDisposable: Disposable {
    var retained: AnyObject!
    let disposable: Disposable
    
    init (retaining retained: AnyObject, disposing disposable: Disposable) {
        self.retained = retained
        self.disposable = disposable
    }
    
    func dispose() {
        retained = nil
        disposable.dispose()
    }
}

// swiftlint:disable line_length

public extension Observable {
    func bind<RowType: UITableViewCell, T: Hashable>(to tableView: UITableView,
                                                           reusing reuseIdentifier: String,
                                                           with adapter: @escaping ((RowType, T) -> RowType)) -> Disposable where E == [T] {
        return ObservableList<T>.diff(self)
            .bind(to: tableView, reusing: reuseIdentifier, with: adapter)
    }
}

public extension ObservableList {
    
    func bind<RowType: UITableViewCell>(to tableView: UITableView,
                                              reusing reuseIdentifier: String,
                                              with adapter: @escaping ((RowType, T) -> RowType)) -> Disposable {
        return bind(to: tableView,
                    reusing: reuseIdentifier,
                    with: { cell, _, value -> RowType in return adapter(cell, value) })
    }
    
    func bind<RowType: UITableViewCell>(to tableView: UITableView,
                                              reusing reuseIdentifier: String,
                                              with adapter: @escaping ((RowType, IndexPath, T) -> RowType)) -> Disposable {
        return bind(to: tableView,
                    with: { tableView, indexPath, value -> RowType in
                        
                        // swiftlint:disable:next force_cast
                        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! RowType
                        
                        return adapter(cell, indexPath, value)
        })
    }
    
    func bind<RowType: UITableViewCell>(to tableView: UITableView,
                                              with adapter: @escaping ((UITableView, IndexPath, T) -> RowType)) -> Disposable {
        let dataSource = ObservableListTableViewDataSource(list: self.updates, rowCreator: adapter)
        let disposable = dataSource.bind(to: tableView)
        
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}

// swiftlint:enable line_length
