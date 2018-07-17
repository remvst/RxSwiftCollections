//
//  ObservableList+IGListKit.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-07-17.
//

import UIKit
import RxSwift
import IGListKit

private class WrappedSnowflake<T>: NSObject, ListDiffable {
    fileprivate let diffIndex: Int
    let index: Int
    private let ownedList: LazyCollection<[T]>
    
    init(relativeTo diffIndex: Int, atIndex index: Int, withList ownedList: LazyCollection<[T]>) {
        self.diffIndex = diffIndex
        self.index = index
        self.ownedList = ownedList
    }
    
    var value: T {
        return ownedList[index]
    }
    
    func diffIdentifier() -> NSObjectProtocol {
        return diffIndex as NSNumber
    }
    
    func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
        guard let other = object as? WrappedSnowflake<T>? else {
            return false
        }
        
        return other?.diffIndex == diffIndex
    }
}

private class ObservableIGDataSource<T>: NSObject, ListAdapterDataSource {
    
    private var currentList: LazyCollection<[T]>
    private var wrappedCurrentList: [WrappedSnowflake<T>]
    private let observableList: Observable<Update<T>>
    private var nextSequenceId: Int = 0
    private let sectionCreator: ((ListAdapter, Int) -> BindingListSectionController<T>)
    
    init(wrapping wrappedList: Observable<Update<T>>,
         sectionCreator: @escaping ((ListAdapter, Int) -> BindingListSectionController<T>)) {
        self.observableList = wrappedList
        self.currentList = [].lazy
        self.wrappedCurrentList = []
        self.sectionCreator = sectionCreator
    }
    
    func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
        return wrappedCurrentList
    }
    
    func listAdapter(_ listAdapter: ListAdapter, sectionControllerFor object: Any) -> ListSectionController {
        // swiftlint:disable force_cast
        let object = object as! WrappedSnowflake<T>
        // swiftlint:enable force_cast
        
        return sectionCreator(listAdapter, object.index)
    }
    
    func emptyView(for listAdapter: ListAdapter) -> UIView? {
        return nil
    }
    
    func bind(to listAdapter: ListAdapter) -> Disposable {
        return self.observableList
            .observeOn(MainScheduler.instance)
            .concatMap({ [weak self] update -> Completable in
                guard let this = self else {
                    return Completable.empty()
                }
                
                guard update.changes.first(where: { (change) -> Bool in
                    if case .reload = change {
                        return true
                    }
                    
                    return false
                }) == nil else {
                    return Completable.create(subscribe: { observer -> Disposable in
                        this.currentList = update.list
                        let count = this.currentList.count
                        
                        var wrappedList: [WrappedSnowflake<T>] = []
                        
                        for i in 0..<count {
                            let diffIndex = this.nextSequenceId + 1
                            
                            this.nextSequenceId += 1
                            
                            let wrapper = WrappedSnowflake<T>(relativeTo: diffIndex, atIndex: i, withList: update.list)
                            
                            wrappedList.append(wrapper)
                        }
                        
                        this.wrappedCurrentList = wrappedList
                        
                        listAdapter.reloadData(completion: { _ in
                            observer(CompletableEvent.completed)
                        })
                        
                        return Disposables.create()
                    })
                }
                
                return Completable.create(subscribe: { observer -> Disposable in
                    let previousList = this.wrappedCurrentList
                    
                    var diffableIndices = previousList.map({ snowflake -> Int in
                        return snowflake.diffIndex
                    })
                    
                    update.changes.forEach { change in
                        let nextId = this.nextSequenceId
                        
                        this.nextSequenceId += 1
                        
                        switch change {
                        case .insert(let index):
                            diffableIndices.insert(nextId, at: index)
                        case .delete(let index):
                            if diffableIndices.count <= index {
                                diffableIndices.remove(at: diffableIndices.count - 1)
                            } else {
                                diffableIndices.remove(at: index)
                            }
                        case .move(let from, let to):
                            let removed = diffableIndices.remove(at: from)
                            diffableIndices.insert(removed, at: to)
                        case .reload:
                            break
                        }
                    }
                    
                    var wrappedList: [WrappedSnowflake<T>] = []
                    
                    for i in 0..<diffableIndices.count {
                        let diffIndex = diffableIndices[i]
                        let wrapper = WrappedSnowflake<T>(relativeTo: diffIndex, atIndex: i, withList: update.list)
                        
                        wrappedList.append(wrapper)
                    }
                    
                    this.currentList = update.list
                    this.wrappedCurrentList = wrappedList
                    
                    listAdapter.performUpdates(animated: true, completion: { _ in
                        observer(CompletableEvent.completed)
                    })
                    
                    return Disposables.create()
                })
            })
            .subscribe()
    }
}

public class BindingListSectionController<T>: ListSectionController {
    private var model: WrappedSnowflake<T>?
    
    func sizeForItem(at index: Int, with value: T) -> CGSize {
        return CGSize(width: collectionContext!.containerSize.width, height: 55)
    }
    
    func cellForItem(at index: Int, with value: T) -> UICollectionViewCell {
        fatalError("Not implemented")
    }
    
    final public override func sizeForItem(at index: Int) -> CGSize {
        return sizeForItem(at: index, with: model!.value)
    }
    
    final public override func cellForItem(at index: Int) -> UICollectionViewCell {
        return cellForItem(at: index, with: model!.value)
    }
    
    final public override func didUpdate(to object: Any) {
        // swiftlint:disable force_cast
        model = object as! WrappedSnowflake<T>
        // swiftlint:enable force_cast
    }
}

private class SimpleListSectionController<T, CellType: UICollectionViewCell>: BindingListSectionController<T> {
    private let adapter: ((CellType, Int, T) -> CellType)
    private let nibName: String
    
    init(with adapter: @escaping ((CellType, Int, T) -> CellType), withNibName nibName: String) {
        self.adapter = adapter
        self.nibName = nibName
    }
    
    override func cellForItem(at index: Int, with value: T) -> UICollectionViewCell {
        guard let cell = collectionContext?.dequeueReusableCell(withNibName: nibName,
                                                                bundle: nil,
                                                                for: self,
                                                                at: index) as? CellType else {
                                                                    fatalError("Can't create cell")
        }
        
        // swiftlint:disable force_cast
        return adapter(cell, index, value as! T)
        // swiftlint:enable force_cast
    }
}

public extension ObservableList {
    func bind<CellType: UICollectionViewCell>(to listAdapter: ListAdapter,
                                              withNibName nibName: String,
                                              with adapter: @escaping ((CellType, T) -> CellType)) -> Disposable {
        return bind(to: listAdapter,
                    withNibName: nibName,
                    with: { cell, _, value -> CellType in return adapter(cell, value) })
    }
    
    func bind<CellType: UICollectionViewCell>(to listAdapter: ListAdapter,
                                              withNibName nibName: String,
                                              with adapter: @escaping ((CellType, Int, T) -> CellType)) -> Disposable {
        return bind(to: listAdapter,
                    with: { _, _ -> BindingListSectionController<T> in
                        return SimpleListSectionController<T, CellType>(with: adapter, withNibName: nibName)
        })
    }
    
    func bind(to listAdapter: ListAdapter,
              with sectionCreator: @escaping ((ListAdapter, Int) -> BindingListSectionController<T>)) -> Disposable {
        
        let dataSource = ObservableIGDataSource(wrapping: updates, sectionCreator: sectionCreator)
        let disposable = dataSource.bind(to: listAdapter)
        
        listAdapter.dataSource = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}

