//
//  PreviewContactVC.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/22.
//

import UIKit

class PreviewContactVC: MIBaseViewController {

    lazy var contactTabble: UITableView = {
        
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.rowHeight = 60
           
        tableView.delegate = self
        tableView.dataSource = self
        let nib = UINib(nibName: "MIContactTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "MIContactTableViewCell")
            
        return tableView
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
     
        self.contentView.addSubview(contactTabble)
        contactTabble.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalTo(0)
            //make.edges.equalToSuperview()
        }
        
    }
}




extension PreviewContactVC:UITableViewDelegate,UITableViewDataSource{
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 5
    }

    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MIContactTableViewCell", for: indexPath) as! MIContactTableViewCell
        
//        if isSearch {
//            cell.model = searchContacts[indexPath.row]
//        }else{
//            let modelArray = addressBookSouce[keysArray[indexPath.section]]
//            let model = modelArray?[indexPath.row]
//            cell.model = model
//        }
//        
    
        cell.selectClick = {[weak self] in
          
            
           // self?.selectionAction()
//
//            for model in self?.tempArr ?? [] {
//                if model?.isSelect == false {
//                    self?.selectAllBtn.isSelected = false
//                    break
//                }
//            }
//
//            for model in self?.tempArr ?? []{
//                if model?.isSelect == true {
//                    self?.finishBtn.isEnabled = true
//                    self?.finishBtn.alpha = 1
//                    break
//                }
//            }
        }
        
    
        return cell
    }
  
    
  
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return  0.01
//    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return   50
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//
//
//        let modelArray = addressBookSouce[keysArray[indexPath.section]]
//        let model = modelArray?[indexPath.row]
//
//        model?.isSelect = !(model?.isSelect ?? false)
//
//        tableView.reloadRows(at: [indexPath], with: .none)
//
//        //stateBtn.isSelected = model?.isSelect ?? false
//      }

}
