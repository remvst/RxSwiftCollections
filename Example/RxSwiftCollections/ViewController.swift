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
        ObservableList<String>.of([Int](1...256))
            .map { "Test \($0)" }
    }
}
