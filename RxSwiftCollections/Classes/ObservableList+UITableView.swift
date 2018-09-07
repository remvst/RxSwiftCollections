//
//  ObservableList+UITableView.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-07-06.
//

import RxSwift

private class ObservableListTableViewDataSource<T>: NSObject, UITableViewDelegate, UITableViewDataSource {

    typealias SelectedHandlerClosure = (UITableView, IndexPath, T) -> Void
    typealias RowCreatorClosure = (UITableView, IndexPath, T) -> UITableViewCell
    typealias UpdatesCompletionClosure = (UITableView) -> Void

    private var currentList: LazyCollection<[T]>?
    private let observableList: Observable<Update<T>>
    private let rowCreator: RowCreatorClosure
    private let didSelectHandler: SelectedHandlerClosure
    private let updatesCompletionHandler: UpdatesCompletionClosure

    private var hasCalledNumberOfRows = false

    var disposable: Disposable!

    init(list: Observable<Update<T>>,
         rowCreator: @escaping RowCreatorClosure,
         didSelectHandler: @escaping SelectedHandlerClosure,
         updatesCompletionHandler: @escaping UpdatesCompletionClosure) {
        self.observableList = list
        self.rowCreator = rowCreator
        self.didSelectHandler = didSelectHandler
        self.updatesCompletionHandler = updatesCompletionHandler
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentList?.count ?? 0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // swiftlint:disable:next force_unwrapping
        let item = currentList![indexPath.item]
        didSelectHandler(tableView, indexPath, item)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable:next force_unwrapping
        let item = currentList![indexPath.item]

        return rowCreator(tableView, indexPath, item)
    }

    func bind(to tableView: UITableView) -> Disposable {
        return self.observableList
            .observeOn(MainScheduler.instance)
            .concatMap({ [weak self] (update) -> Completable in
                guard let this = self else {
                    return Completable.empty()
                        .subscribeOn(MainScheduler.instance)
                }

                guard update.changes.first(where: { (change) -> Bool in
                    if case .reload = change {
                        return true
                    }

                    return false
                }) == nil, this.currentList != nil else {
                    this.currentList = update.list
                    tableView.reloadData()

                    return Completable.empty()
                        .do(onCompleted: {
                            this.updatesCompletionHandler(tableView)
                        })
                        .subscribeOn(MainScheduler.instance)
                }

                tableView.beginUpdates()
                this.currentList = update.list

                update.changes.forEach { change in
                    switch change {
                    case .insert(let index):
                        tableView.insertRows(at: [IndexPath(item: index, section: 0)],
                                             with: UITableViewRowAnimation.automatic)
                    case .delete(let index):
                        tableView.deleteRows(at: [IndexPath(item: index, section: 0)],
                                             with: UITableViewRowAnimation.automatic)
                    case .move(let from, let to):
                        tableView.moveRow(at: IndexPath(item: from, section: 0),
                                          to: IndexPath(item: to, section: 0))
                    case .reload:
                        break
                    }
                }

                tableView.endUpdates()
                return Completable.empty()
                    .do(onCompleted: {
                        this.updatesCompletionHandler(tableView)
                    })
                    .subscribeOn(MainScheduler.instance)
            })

            .subscribe(onNext: { _ in
            }, onError: { (_) in
            }, onCompleted: {
            })
    }
}

public extension Observable {
    func bind<RowType: UITableViewCell, T: Hashable>
        (to tableView: UITableView,
         reusing reuseIdentifier: String,
         with adapter: @escaping ((RowType, T) -> RowType),
         onSelected selected: @escaping (T) -> Void,
         onUpdatesCompleted updatesCompleted: @escaping (UITableView) -> Void) -> Disposable where E == [T] {

        return ObservableList<T>.diff(self)
            .bind(to: tableView,
                  reusing: reuseIdentifier,
                  with: adapter,
                  onSelected: selected,
                  onUpdatesCompleted: updatesCompleted)
    }
}

public extension ObservableList {

    func bind<RowType: UITableViewCell>
        (to tableView: UITableView,
         reusing reuseIdentifier: String,
         with adapter: @escaping ((RowType, T) -> RowType),
         onSelected selected: @escaping (T) -> Void,
         onUpdatesCompleted updatesCompleted: @escaping (UITableView) -> Void) -> Disposable {

        return bind(to: tableView,
                    reusing: reuseIdentifier,
                    with: { cell, _, value -> RowType in return adapter(cell, value) },
                    onSelected: selected,
                    onUpdatesCompleted: updatesCompleted)
    }

    func bind<RowType: UITableViewCell>
        (to tableView: UITableView,
         reusing reuseIdentifier: String,
         with adapter: @escaping ((RowType, IndexPath, T) -> RowType),
         onSelected selected: @escaping (T) -> Void,
         onUpdatesCompleted updatesCompleted: @escaping (UITableView) -> Void) -> Disposable {

        return bind(to: tableView,
                    with: { tableView, indexPath, value -> RowType in

                        // swiftlint:disable force_cast
                        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier,
                                                                 for: indexPath) as! RowType
                        // swiftlint:enable force_cast

                        return adapter(cell, indexPath, value)
        },
                    onSelected: { _, _, value -> Void in
                        selected(value)
        }, onUpdatesCompleted: updatesCompleted)
    }

    func bind<RowType: UITableViewCell>
        (to tableView: UITableView,
         with adapter: @escaping ((UITableView, IndexPath, T) -> RowType),
         onSelected selected: @escaping (UITableView, IndexPath, T) -> Void,
         onUpdatesCompleted updatesCompleted: @escaping (UITableView) -> Void) -> Disposable {

        let dataSource = ObservableListTableViewDataSource(list: self.updates,
                                                           rowCreator: adapter,
                                                           didSelectHandler: selected,
                                                           updatesCompletionHandler: updatesCompleted)

        let disposable = dataSource.bind(to: tableView)

        tableView.dataSource = dataSource
        tableView.delegate = dataSource

        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}

// swiftlint:enable line_length
