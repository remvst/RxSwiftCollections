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

class ViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    fileprivate let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cellNib = UINib(nibName: "DemoCollectionViewCell", bundle: nil)
        
        collectionView.register(cellNib, forCellWithReuseIdentifier: "Demo")
        
        self.setup()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension ViewController {
    
    func setup() {
        let list: SimpleObservableList<Int> = SimpleObservableList([Int](1...10))
        let tick: Observable<Int> = Observable.interval(0.2, scheduler: MainScheduler.instance)
            
        tick
            .subscribe { event in
                guard case let .next(data) = event else {
                    return
                }
                
                list.append(data + 11)
            }
            .disposed(by: disposeBag)
        
        // ObservableList<String>.of([Int](1...256))
        
        list.map { "\($0)" }
            .bind(to: self.collectionView, reusing: "Demo", with: { (cell, text) -> DemoCollectionViewCell in
                cell.titleLabel.text = text
                
                return cell
            })
            .disposed(by: disposeBag)
    }
}
