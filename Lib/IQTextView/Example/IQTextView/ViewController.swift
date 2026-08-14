//
//  ViewController.swift
//  IQTextView
//
//  Created by hackiftekhar on 07/22/2024.
//  Copyright (c) 2024 hackiftekhar. All rights reserved.
//

import UIKit
import IQTextView

class ViewController: UIViewController {

    @IBOutlet private var textView: IQTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.contentInset = .init(top: 8, left: 8, bottom: 8, right: 8)
        // Do any additional setup after loading the view, typically from a nib.
    }
}
