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
        for _ in 0..<(!isEmpty ? (count - 1) : 0) {
            sort { (_, _) in arc4random() < arc4random() }
        }
    }
}

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    fileprivate let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cellNib = UINib(nibName: "DemoTableViewCell", bundle: nil)
        
        tableView.register(cellNib, forCellReuseIdentifier: "Demo")
        
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
        let randomIntStream = Observable<Int>
            .interval(2.0, scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
            .scan(original, accumulator: { (previous, _) -> [Int] in
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
            
        ObservableList<Int>
            .diff(randomIntStream)
            .map { "\($0)" }
            .bind(to: self.tableView,
                  reusing: "Demo",
                  with: { (cell, text) -> DemoTableViewCell in
                    cell.titleLabel.text = text
                    
                    return cell
            }, onSelected: { text in
                print("selected: \(text)")
            }, onUpdatesCompleted: { (_, _) in
                print("updates completed")
            })
            .disposed(by: disposeBag)
    }
}
