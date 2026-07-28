//
//  AddressBook.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/4.
//

import Foundation
import UIKit
import Contacts
import ContactsUI

class AddressBook:NSObject {
    
    typealias SucessBlock = (_ contacts: [String:String]?,_ navVC :UIViewController?) -> Void
   
//    typealias ClickBlockVoid = (_ contacts:[AddressBookModel?]?)->()
//
//    var selectContacts : ClickBlockVoid?
    
    
    func selectContactsAction(autoDismiss:Bool = false ,sucess: @escaping SucessBlock,fail:@escaping ClickBlockVoid) {
   
     
            //1.获取授权状态
            let status = CNContactStore.authorizationStatus(for: .contacts)
            //2.判断授权状态，如果未授权，发起授权请求,如果已授权，就直接遍历通讯录获取数据
            
            if status == .notDetermined {
                let contactStore = CNContactStore()
                contactStore.requestAccess(for: .contacts, completionHandler: { (isAllow: Bool, nil) in
                    
                    //同意
                    if isAllow {
                        
                        self.getContactsList(autoDismiss:autoDismiss,sucess: sucess,fail: fail)
                        
                    }
                    //不允许
                    else{
                        DispatchQueue.main.async {
                            AlertManager.showAlert(title: "提示".localized,message: "去设置界面开启允许通讯录选择".localized,cancelTitle: "取消".localized,cancelAction: {
                                fail()
                                
                            },confirmTitle: "设置".localized,confirmAction:{
                                fail()
                                if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                                    UIApplication.shared.open(url)
                                }
                            })
                        }
                      
                            
                    }
                })
            }else if status == .authorized{
                //遍历联系人列表
          
                self.getContactsList(autoDismiss:autoDismiss,sucess: sucess,fail: fail)
                
            }else {
                if #available(iOS 18.0, *){
                    if status == .limited{
                        ShareAPI.shared().log(1, "通讯录受限访问：limited")
                        self.getContactsList(autoDismiss:autoDismiss,sucess: sucess,fail: fail)
                    }else{
                        AlertManager.showAlert(title: "提示".localized,message: "去设置界面开启允许通讯录选择".localized,cancelTitle: "取消".localized,cancelAction: {
                            fail()
                            
                        },confirmTitle: "设置".localized,confirmAction:{
                            if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                                UIApplication.shared.open(url)
                            }
                            
                        })
                    }
                }else{
                    AlertManager.showAlert(title: "提示".localized,message: "去设置界面开启允许通讯录选择".localized,cancelTitle: "取消".localized,cancelAction: {
                        fail()
                        
                    },confirmTitle: "设置".localized,confirmAction:{
                        if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                            UIApplication.shared.open(url)
                        }
                        
                    })
                }
            }
        }
    
}


extension AddressBook {

    /*
     *调用时间：
     *作用：遍历通讯录
     */
    private func getContactsList(autoDismiss:Bool,sucess: @escaping SucessBlock,fail:@escaping ClickBlockVoid) {
        
        //判断是否有权读取通讯录
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if #available(iOS 18.0, *) {
            guard status == .authorized || status == .limited else {
                fail()
                return
            }
        } else {
            guard status == .authorized else {
                fail()
                return
            }
            // Fallback on earlier versions
        }
        
        
        let fetchKeys = [CNContactFormatter.descriptorForRequiredKeys(for: CNContactFormatterStyle.fullName),CNContactPhoneNumbersKey,CNContactThumbnailImageDataKey] as [Any]
        let fetchRequest = CNContactFetchRequest.init(keysToFetch: fetchKeys as! [CNKeyDescriptor]);
       
        
        //请求获取联系人
        var contacts = [CNContact]()
        let contactStore = CNContactStore.init()
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { ( contact, stop) -> Void in
                contacts.append(contact)
            })
            
        }
        catch let error as NSError {
            print(error.localizedDescription)
        }
        
        var addressBookDict = [String:[AddressBookModel]]()

        
        
        
        // 3.1遍历联系人
        for contact in contacts {
            
//            do {
//                let newData = try NSKeyedArchiver.archivedData(withRootObject: [contact], requiringSecureCoding: true)
//                exportContact(contactData: newData)
//                
//                
//             
//            } catch {
//                print("Error exporting contact to VCF: \(error)")
//                return
//            }
//            
//            archivedData(withRootObject: contact)
            
            
//            NSKeyedArchiver
            
//            do {
//
//            let vcfString = try CNContactVCardSerialization.data(with: [contact])
//                  let aa = String(data: vcfString, encoding: .utf8)
//                return
//             } catch {
//                 print("Error exporting contact to VCF: \(error)")
//                 return
//             }
//            
//            
//            do {
//                let  _ = try CNContactVCardSerialization.data(with: contacts)
//                let fileURL = FileManager.default
//                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
//                    .appendingPathComponent("contacts.vcf")
//            }
//            catch let error as NSError {
//                print(error.localizedDescription)
//            }
            
            
            // 创建联系人模型
            let model = AddressBookModel()
            model.contact = contact
            
            // 获取联系人全名
            model.name = CNContactFormatter.string(from: contact, style: CNContactFormatterStyle.fullName) ?? "无名氏"
            
            // 获取头像
            let imageData = contact.thumbnailImageData ?? NSData.init() as Data
            model.headerImage = UIImage.init(data: imageData)
            
//            if let data = try? NSKeyedArchiver.archivedData(withRootObject: contact, requiringSecureCoding: false) {
//                model.totalSize = data.count
//            }
            // 遍历一个人的所有电话号码
            for labelValue in contact.phoneNumbers {
                let phoneNumber = labelValue.value
                model.mobileArray.append(phoneNumber.stringValue)
             
            }
            
            // 获取到姓名的大写首字母
            let firstLetterString = getFirstLetterFromString(aString: model.name)
            
            
            if addressBookDict[firstLetterString] != nil {
                // swift的字典,如果对应的key在字典中没有,则会新增
                addressBookDict[firstLetterString]?.append(model)
                
            } else {
                let arrGroupNames = [model]
                //arrGroupNames.append(model)
                addressBookDict[firstLetterString] = arrGroupNames
            }
            
            // 将联系人模型回调出去
//            success(model)
        }
        
        var nameKeys = Array(addressBookDict.keys).sorted()
        
        if nameKeys.first == "#" {
            nameKeys.insert(nameKeys.first!, at: nameKeys.count)
            nameKeys.remove(at: 0);
        }
        
      
        DispatchQueue.main.async {
            let contactVC = MIContactViewController()
            contactVC.autoDismiss = autoDismiss
            contactVC.addressBookSouce = addressBookDict  // 所有联系人信息的字典
            contactVC.keysArray = nameKeys       // 所有分组的key值
            
            let naviController = MIBaseNavigationViewController(rootViewController: contactVC)
            
            
         
            contactVC.selectContacts = { contacts in
             
                sucess(contacts,contactVC)
               // self?.selectContacts?(contacts)
                
            }
            contactVC.fail = {
               
                fail()
            }

            if let topVC = MIGetTopViewController() {
                naviController.modalPresentationStyle = .formSheet
                
                // 设置首选内容大小
                naviController.preferredContentSize = CGSize(
                    width: topVC.view.bounds.width,
                    height: topVC.view.bounds.height * 0.7
                )
                
                topVC.present(naviController, animated: true)
            }

            
//            contactVC.modalPresentationStyle = .overCurrentContext
//            contactVC.modalPresentationStyle = .fullScreen
            //MIGetTopViewController()?.present(naviController, animated: true)
            
//            .navigationController?.pushViewController(contactVC, animated: true)
        }
        
    }

}


extension AddressBook: CNContactPickerDelegate {
    
    func fetchContacts(_ keysToFetch: [CNKeyDescriptor]) {
        
        let contactStore = CNContactStore()
        
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts = [CNContact]()
       
        
        var contactsDict = [String: [CNContact]]()
     
        do {
            try contactStore.enumerateContacts(with: fetchRequest) { (contact, stop) in
                contacts.append(contact)
            }
            
            // 对联系人按姓名首字母排序
            contacts.sort { (contact1, contact2) -> Bool in
                if let firstName1 = contact1.givenName.first, let firstName2 = contact2.givenName.first {
                    return firstName1 < firstName2
                }
                return false
            }
            
            // 分组联系人
            for contact in contacts {
                if let firstLetter = contact.givenName.first?.uppercased() {
                    if contactsDict[firstLetter] == nil {
                        contactsDict[firstLetter] = [contact]
                    } else {
                        contactsDict[firstLetter]?.append(contact)
                    }
                }
            }
            
            // 打印或处理分组后的联系人数据
            for (key, value) in contactsDict {
                print("\(key): \(value.map { $0.givenName })")
            }
            
        } catch {
            print("Error fetching contacts: \(error)")
        }
    }

    
    //单选联系人
//       func contactPicker(_ picker: CNContactPickerViewController,
//                          didSelect contact: CNContact) {
//           //获取联系人的姓名
//           let lastName = contact.familyName
//           let firstName = contact.givenName
//           print("选中人的姓：\(lastName)")
//           print("选中人的名：\(firstName)")
//
//           //获取联系人电话号码
//           print("选中人电话：")
//           let phones = contact.phoneNumbers
//           for phone in phones {
//               //获得标签名（转为能看得懂的本地标签名，比如work、home）
//               let phoneLabel = CNLabeledValue<NSString>.localizedString(forLabel: phone.label!)
//               //获取号码
//               let phoneValue = phone.value.stringValue
//               print("\(phoneLabel):\(phoneValue)")
//           }
//       }
    
    
    //多选联系人
       func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
           print("一共选择了\(contacts.count)个联系人。")
           for contact in contacts {
               print("--------------")
               //获取联系人的姓名
               let lastName = contact.familyName
               let firstName = contact.givenName
               print("选中人的姓：\(lastName)")
               print("选中人的名：\(firstName)")
                
               //获取联系人电话号码
               print("选中人电话：")
               let phones = contact.phoneNumbers
               for phone in phones {
                   //获得标签名（转为能看得懂的本地标签名，比如work、home）
                   let phoneLabel = CNLabeledValue<NSString>.localizedString(forLabel: phone.label!)
                   //获取号码
                   let phoneValue = phone.value.stringValue
                   print("\(phoneLabel):\(phoneValue)")
               }
           }
       }
        
//
//    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
//        // 处理选中的联系人
//        //4.2获取电话号码
//        let phoneNumbers = contact.phoneNumbers
//
//        if phoneNumbers.count == 0 || (contact.givenName == "" && contact.familyName == "") {
//
////            self.view.makeToast("The phone or name is empty,please select another.", point: self.view.center, title: nil, image: nil) { didTap in
////
////            }
//
//            return
//        }
////        for phoneNumber in phoneNumbers {
////            print(phoneNumber.value.stringValue)
////            //telModel.tel = phoneNumber.value.stringValue
////        }
////        informationModel?.gnar?.electren?[self.contatIndex.section].olivature = phoneNumbers.first?.value.stringValue
////
////        informationModel?.gnar?.electren?[self.contatIndex.section].scientisttic = "\(contact.givenName) \(contact.familyName)"
////        self.informationTabbleView.reloadRows(at: [self.contatIndex], with: .none)
////
////        print("Selected contact: \(contact.givenName) \(contact.familyName)")
//    }
//
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        // 用户取消选择
        print("Contact picker was cancelled")
    }
}


// MARK: - 获取联系人姓名首字母(传入汉字字符串, 返回大写拼音首字母)
func getFirstLetterFromString(aString: String) -> (String) {
    
    // 注意,这里一定要转换成可变字符串
    let mutableString = NSMutableString.init(string: aString)
    // 将中文转换成带声调的拼音
    CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformToLatin, false)
    // 去掉声调(用此方法大大提高遍历的速度)
    let pinyinString = mutableString.folding(options: String.CompareOptions.diacriticInsensitive, locale: NSLocale.current)
    // 将拼音首字母装换成大写
    let strPinYin = polyphoneStringHandle(nameString: aString, pinyinString: pinyinString).uppercased()
    // 截取大写首字母
    let firstString = strPinYin.prefix(1)
    
    //strPinYin.substring(to: strPinYin.index(strPinYin.startIndex, offsetBy:1))
    // 判断姓名首位是否为大写字母
    let regexA = "^[A-Z]$"
    let predA = NSPredicate.init(format: "SELF MATCHES %@", regexA)
    return String(predA.evaluate(with: firstString) ? firstString : "#")
}

// MARK: - 获取联系人姓名拼音(传入汉字字符串, 返回拼音)
func getNameLetterFromString(aString: String) -> (String) {
    
    // 注意,这里一定要转换成可变字符串
    let mutableString = NSMutableString.init(string: aString)
    // 将中文转换成带声调的拼音
    CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformToLatin, false)
    // 去掉声调(用此方法大大提高遍历的速度)
    let pinyinString = mutableString.folding(options: String.CompareOptions.diacriticInsensitive, locale: NSLocale.current)
    return pinyinString
}


/// 多音字处理
func polyphoneStringHandle(nameString:String, pinyinString:String) -> String {
    if nameString.hasPrefix("长") {return "chang"}
    if nameString.hasPrefix("沈") {return "shen"}
    if nameString.hasPrefix("厦") {return "xia"}
    if nameString.hasPrefix("地") {return "di"}
    if nameString.hasPrefix("重") {return "chong"}
    
    return pinyinString;
}


func calculateContactsSize(contacts: [CNContact]) -> Int {
    var totalSize = 0
    for contact in contacts {
        if let jsonData = try? JSONSerialization.data(withJSONObject: [contact.givenName, contact.familyName, contact.phoneNumbers.map({ $0.value.stringValue })], options: []) {
            totalSize += jsonData.count
        }
    }
    return totalSize
}


//let fileManager = FileManager.default
//let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
//if let dirPath = paths.first {
//    let filePath = URL(fileURLWithPath: dirPath).appendingPathComponent("contacts.json")
//    do {
//        try jsonData?.write(to: filePath)
//        let attributes = try fileManager.attributesOfItem(atPath: filePath.path)
//        if let fileSize = attributes[FileAttributeKey.size] as? NSNumber {
//            print("File size: \(fileSize)") // 单位为字节
//        }
//    } catch {
//        print("Error writing file")
//    }
//}






//func saveVCFToFile(_ vcfString: String, fileName: String) {
//    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
//    let filePath = (documentsPath as NSString).appendingPathComponent(fileName)
//    do {
//        try vcfString.write(toFile: filePath, atomically: true, encoding: .utf8)
//        print("VCF file saved to: \(filePath)")
//    } catch {
//        print("Error saving VCF file: \(error)")
//    }
//}


 
//func exportContact(contactData: Data) -> URL? {
//    
//    
//    do {
//        let aa = try CNContactVCardSerialization.contacts(with: contactData)
//        
//        print("======")
//        aa.first?.givenName
//        aa.first?.phoneNumbers
//        print(aa.first?.familyName ?? "")
//    } catch {
//        print("Error exporting contact to VCF: \(error)")
//        return nil
//    }
//  
//    
//   
//    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//    let fileURL = documentsURL.appendingPathComponent("contact.vcf")
//    do {
//        try contactData.write(to: fileURL)
//        return fileURL
//    } catch {
//        print("Error writing to file: \(error)")
//        return nil
//    }
//}




//    .vcf）解析成iOS中的CNContact
//// responseObject = URL.init(fileURLWithPath: "/var/***/contacts.vcf")
//let tempData = try? Data.init(contentsOf: responseObject as! URL)
//let vcardStr = String.init(data: tempData!, encoding: String.Encoding.utf8)
//let vcardstr2 = NSString.init(replaceEncodeWith: vcardStr)
//let goalData = vcardstr2?.data(using: String.Encoding.utf8.rawValue)
//                
//let contacts = try? CNContactVCardSerialization.contacts(with: goalData!)


//import PinyinHelper
//
//func searchWithPinyin(text: String, keyword: String) -> Bool {
//    if let pinyin = PinyinHelper.toHanyuPinyinStringArray(withString: text) {
//        let pinyinString = pinyin.joined(separator: "")
//        return pinyinString.contains(keyword)
//    }
//    return false
//}
//
//// 示例使用
//let text = "苹果"
//let keyword = "ping"
//let result = searchWithPinyin(text: text, keyword: keyword)
//print(result)  // 输出：true 或 false，取决于是否匹配
