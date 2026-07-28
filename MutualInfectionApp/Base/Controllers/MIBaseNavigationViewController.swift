//
//  MIBaseNavigationViewController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/1.
//

import UIKit

class MIBaseNavigationViewController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override var childForStatusBarStyle: UIViewController? {

        return topViewController

    }
    deinit {
        print("deinit:释放============\(self)")
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
