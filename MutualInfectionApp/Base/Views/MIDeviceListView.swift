//
//  MIDeviceListView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/1.
//

import UIKit

class MIDeviceListView: UIView {

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView()
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.register(MIDeviceItem.self, forCellWithReuseIdentifier: "MIDeviceItem")
        
        return collectionView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
}

extension MIDeviceListView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        100
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MIDeviceItem", for: indexPath)
        
        return cell
    }
    
    
}

extension MIDeviceListView: UICollectionViewDelegate {
    
}

