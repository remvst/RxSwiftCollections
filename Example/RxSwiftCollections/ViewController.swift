//
//  ViewController.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 05/19/2018.
//  Copyright (c) 2018 Mike Roberts. All rights reserved.
//

import UIKit
import RxSwift
import RxSwiftCollections
import IGListKit

extension Array {
    mutating func shuffle() {
        for _ in 0..<(!isEmpty ? (count - 1) : 0) {
            sort { (_, _) in arc4random() < arc4random() }
        }
    }
}

final class ViewController: UIViewController {
    var adapter: ListAdapter?
    
    @IBOutlet weak var collectionView: UICollectionView?
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let collectionView = collectionView else {
            return
        }
        
        view.addSubview(collectionView)
        
        let cellNib = UINib(nibName: "DemoCollectionViewCell", bundle: nil)
        
        collectionView.register(cellNib, forCellWithReuseIdentifier: "Demo")
    
        let original = Array([
            "A", "B", "C", "D", "E", "F", "G", "H",
            "I", "J", "K", "L", "M", "N", "O", "P",
            "Q", "R", "S", "T", "U", "V", "W", "X",
            "Y", "Z"])
        let randomCharacterStream = Observable<Int>
            .interval(2.0, scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
            .scan(original, accumulator: { (previous, _) -> [String] in
                var next = Array(previous)
                
                // remove some numbers
                for _ in 0...randomInt(2) {
                    next.remove(at: randomInt(next.count))
                }
                
                // add some numbers back
                let additions = original.filter({ (number) -> Bool in !previous.contains(number) })
                
                if !additions.isEmpty {
                    for i in 0..<additions.count {
                        let position = randomInt(next.count)
                        next.insert(additions[i], at: position)
                    }
                }
                
                return next
            })
            .asObservable()
        
        let listAdapter = ListAdapter(updater: ListAdapterUpdater(), viewController: nil)
        
        ObservableList<String>
            .diff(randomCharacterStream)
            .bind(to: listAdapter,
                  nibName: "DemoCollectionViewCell",
                  sizeAdapter: { (containerSize, _) -> CGSize in
                    return CGSize(width: containerSize.width,
                                  height: 55.0)
            }, cellAdapter: { cell, text -> DemoCollectionViewCell in
                cell.titleLabel.text = text
                
                print(text)
                
                return cell
            })
            .disposed(by: disposeBag)
        
        listAdapter.collectionView = collectionView
    }
}

func randomInt(_ upperBound: Int) -> Int {
    return Int(arc4random_uniform(UInt32(upperBound)))
}
