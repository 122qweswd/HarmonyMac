//
//  MIContactTableViewCell.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/4.
//

import UIKit
import Contacts

class MIContactTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLb: UILabel!
    
    @IBOutlet weak var numberLb: UILabel!
    
    @IBOutlet weak var stateBtn: UIButton!
    var  selectClick: ClickBlockVoid?
    var model : AddressBookModel? {
        didSet{
            
            stateBtn.isSelected = model?.isSelect ?? false
            nameLb.text = model?.name
            nameLb.font = SFCompact(weight: .medium,size: 14)
        
            numberLb.text = model?.mobileArray.joined(separator: ",")
            numberLb.font = SFCompact(weight: .regular,size: 12)
//
//            if let contact  = model?.contact {
                
//                let phoneNumbers = contact.phoneNumbers
//                var tels : [String] = []
//                for phoneNumber in phoneNumbers {
//                    print(phoneNumber.value.stringValue)
//                    tels.append(phoneNumber.value.stringValue)
//                }
                
//                if tels.count > 0 {
//                    numberLb.text = tels.first
//                }
//            }
         
            
        }
    }
    
  
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func clickAction(_ sender: UIButton) {
        
        model?.isSelect = !(model?.isSelect ?? false)
        stateBtn.isSelected = model?.isSelect ?? false
        selectClick?()
        
        
    }
}
