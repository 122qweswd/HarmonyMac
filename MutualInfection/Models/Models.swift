//
//  Models.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit


// MARK: - Selected Content Models
struct SelectedPhoto {
    let image: UIImage
    let identifier: String
    
    init(image: UIImage, identifier: String = UUID().uuidString) {
        self.image = image
        self.identifier = identifier
    }
}

struct SelectedFile {
    let name: String
    let size: String
    let url: URL
}

struct SelectedContact {
    let name: String
    let phone: String
}
