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

extension Array {
    mutating func shuffle() {
        for _ in 0..<((count>0) ? (count-1) : 0) {
            sort { (_,_) in arc4random() < arc4random() }
        }
    }
}

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

func randomInt(_ upperBound: Int) -> Int {
    return Int(arc4random_uniform(UInt32(upperBound)))
}

extension ViewController {
    
    func setup() {
        let removeCount = 100
        let upperBound = 1000
        let original = Array([Int](1...upperBound))
        let randomIntStream: Observable<[Int]> = Observable<Int>.interval(2.0, scheduler: MainScheduler.instance)
            .scan(original, accumulator: { (previous, step) -> [Int] in
                var next = Array(previous)
                
                // remove some numbers
                for _ in 0...randomInt(removeCount) {
                    next.remove(at: randomInt(next.count))
                }
                
                // add some numbers back
                let additions = original.filter({ (number) -> Bool in !previous.contains(number) })
                
                if !additions.isEmpty {
                    for i in 0...randomInt(additions.count) {
                        let position = randomInt(next.count)
                        next.insert(additions[i], at: position)
                    }
                }
                
                return next
            })
            .asObservable()
            
        ObservableList<Int>.diff(randomIntStream.observeOn(ConcurrentDispatchQueueScheduler(qos: .background)))
            .map { "\($0)" }
            .bind(to: self.collectionView, reusing: "Demo", with: { (cell, text) -> DemoCollectionViewCell in
                cell.titleLabel.text = text
                
                return cell
            })
            .disposed(by: disposeBag)
    }
}
