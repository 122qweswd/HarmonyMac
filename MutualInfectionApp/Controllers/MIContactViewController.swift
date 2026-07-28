//
//  MIContactViewController.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/4.
//

import UIKit
import Contacts
import RealityKit

class MIContactViewController: MIBaseViewController {

    /// 所有联系人信息的字典
    var addressBookSouce = [String:[AddressBookModel]]()
    var autoDismiss:Bool = true
    /// 所有分组的key值
    var keysArray = [String]()
    var contacts : [String: [AddressBookModel?]?]?
    
    var contactNames : [String?]? = []
    var tempArr: [AddressBookModel?] = []
    var searchContacts : [AddressBookModel?] = []
    
    typealias SelectContactsVoid = (_ contacts:[String:String]?)->()
    
    var selectContacts : SelectContactsVoid?
    var fail:ClickBlockVoid?
    var isBack:Bool = false
    @IBOutlet weak var backBtn: UIButton!
    
    @IBOutlet weak var finishBtn: UIButton!{
        didSet{
            self.finishBtn.setTitle("完成".localized, for: .normal)
        
        }
    }
    @IBOutlet weak var titleLb: UILabel!{
        didSet{
            titleLb.font = SFCompact(size: 17)
            titleLb.text = "选择联系人".localized
        }
    }
    
    @IBOutlet weak var selectAllBtn: UIButton!{
        didSet{
            selectAllBtn.titleLabel?.font =  pingFangSC(17, weight: .medium)
            selectAllBtn.setTitle("全选".localized, for: .normal)
            selectAllBtn.setTitle("取消全选".localized, for: .selected)
        }
    }
    @IBOutlet weak var previewBtn: UIButton!
    @IBOutlet weak var searchStackView: UIStackView!
    @IBOutlet weak var searchBar: UISearchBar!{
        didSet{
            searchBar.placeholder = "搜索".localized
            searchBar.delegate = self
            searchBar.searchTextField.textColor = .black
        }
    }
    
    @IBOutlet weak var cancleBtn: UIButton!{
        didSet{
            cancleBtn.isHidden = true
            cancleBtn.setTitle("取消".localized, for: .normal)
        }
        
    }
    
    var isSearch:Bool = false
    

    @IBOutlet weak var contactTabble: UITableView!{
        didSet{
            
         
            contactTabble.rowHeight = 60
           
            contactTabble.delegate = self
            contactTabble.dataSource = self
            
            let nib = UINib(nibName: "MIContactTableViewCell", bundle: nil)
            contactTabble.register(nib, forCellReuseIdentifier: "MIContactTableViewCell")
            
           
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationView?.isHidden = true
        
        contactNames = contacts?.keys.sorted()
        self.contentView.isHidden = true
        
        
        for key in keysArray {
            
            if let arr = addressBookSouce[key] {
                tempArr += arr
            }
        }
        
        self.previewBtn.isEnabled = false
        self.finishBtn.isEnabled = false
        self.finishBtn.alpha = 0.5
        
        view.addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if !isBack {
            fail?()
        }
        
    }
    
    /// 空状态视图
    lazy var emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.isUserInteractionEnabled = false
        
        let imageView = UIImageView()
        imageView.image = UIImage.iconEmptyDocument
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = "暂无数据".localized
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = "#A7AAB3".color
        titleLabel.textAlignment = .center
    
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(60)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
    
        return view
    }()
}


extension MIContactViewController:UITableViewDelegate,UITableViewDataSource{
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearch || keysArray.count > 0 {
            emptyStateView.isHidden = true
        } else {
            emptyStateView.isHidden = false
        }
        return isSearch ? 1 : keysArray.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if isSearch {
            return searchContacts.count
        }else{
            let key = keysArray[section]
            let array = addressBookSouce[key]

            return array?.count ?? 0
        }
    }
//    
//    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return keysArray[section]
//    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        
        if isSearch {
            return header
        }
        let title = UILabel()
        title.textColor = .black
        title.text = keysArray[section]
        title.font = SFCompact(weight: .regular,size: 14)
        header.addSubview(title)
        title.snp.makeConstraints {
            $0.verticalEdges.equalToSuperview()
            $0.leading.equalTo(16)
        }
        return header
    }
    
    // 右侧索引
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return keysArray
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MIContactTableViewCell", for: indexPath) as! MIContactTableViewCell
        
        if isSearch {
            cell.model = searchContacts[indexPath.row]
        }else{
            let modelArray = addressBookSouce[keysArray[indexPath.section]]
            let model = modelArray?[indexPath.row]
            cell.model = model
        }
        
    
        cell.selectClick = {[weak self] in
            self?.searchBar.resignFirstResponder()
            
            self?.selectionAction()
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
  
    
  
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearch ? 0.01 : 30
    }
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

extension MIContactViewController:UISearchBarDelegate{
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        searchBarisBeginEditing(isBegin: true)
        isSearch = true
  
        searchContacts = tempArr
        
        contactTabble.reloadData()
    
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        
        if searchText.count == 0 {
            searchContacts = tempArr
            contactTabble.reloadData()
        }else{
            searchContacts.removeAll()
            for model in tempArr {
                let phoneObjects = model?.contact?.phoneNumbers
                if (model?.name.contains(searchText) ?? false ) || phoneObjects?.first(where: {$0.value.stringValue.contains(searchText)}) != nil || getNameLetterFromString(aString: model?.name ?? "").contains(searchText){
                    searchContacts.append(model)
                }
            }
            contactTabble.reloadData()
        }
        
    }
    
    func searchBarisBeginEditing(isBegin:Bool) {
        

        backBtn.isHidden = isBegin
        titleLb.isHidden = isBegin
        selectAllBtn.isHidden = isBegin
        
        cancleBtn.isHidden = !isBegin
                
        searchStackView.snp.remakeConstraints {
            $0.leading.equalTo(15)
            $0.trailing.equalTo(-15)
            if isBegin{
                $0.top.equalTo(titleLb.snp.top).offset(-10)
            }else{
                $0.top.equalTo(titleLb.snp.bottom).offset(15)
            }
        }
    }
}
extension MIContactViewController{
    func selectionAction() {
        if let _ = self.tempArr.first(where: { $0?.isSelect == false}) {
           
            self.selectAllBtn.isSelected = false
        }else{
            self.selectAllBtn.isSelected = true
        }
   
        
   
        let count = self.tempArr.filter { $0?.isSelect == true }.count
        
        previewBtn.setTitle(count == 0 ?  "预览" : "预览(\(count))", for: .normal)
     

        
        if let _ = self.tempArr.first(where: { $0?.isSelect == true}) {
           
            self.finishBtn.isEnabled = true
            self.finishBtn.alpha = 1
            self.previewBtn.isEnabled = true
            self.previewBtn.alpha = 1
        }else{
            self.finishBtn.isEnabled = false
            self.finishBtn.alpha = 0.5
            self.previewBtn.isEnabled = false
            self.previewBtn.alpha = 0.5
        }
        
        
    }
}

extension MIContactViewController{
    @IBAction func backAction(_ sender: UIButton) {
        
        isBack = true
        self.dismiss(animated: true) {
            self.fail?()
        }
//        self.navigationController?.popViewController(animated: true)
    }
    @IBAction func selectAllAction(_ sender: UIButton) {
        
        sender.isSelected = !sender.isSelected
        
        for model in tempArr {
            model?.isSelect = sender.isSelected
        }
        self.contactTabble.reloadData()
        
        selectionAction()
    }
    @IBAction func previewAction(_ sender: UIButton) {
        
        let previewContactVC = PreviewContactVC()
        self.navigationController?.pushViewController(previewContactVC, animated: true)
        
    }
    
    @IBAction func finishAction(_ sender: UIButton) {
        
        //回传数据
        var selectArr: [CNContact?] = []
        
        //var vcfCards: [String] = []
        
        for key in keysArray {
            
            if let arr = addressBookSouce[key] {
                
                for model in arr {
                    if model.isSelect {
                        selectArr.append(model.contact)
                        
//                        let card = createVCDCard(firstName:model.contact. contact["firstName"]!, lastName: contact["lastName"]!, email: contact["email"]!, phone: contact["phone"]!)
//                        vcfCards.append(card)
                    }
                }
                
            }
        }
   
        if selectArr.count > 0 {
            

            if autoDismiss {
                isBack = true
                self.dismiss(animated: true) {
                    
                }
                //self.navigationController?.popViewController(animated: true)
            }
            //let filestr =
           let cardStrArr = VCard21String.generate(with: selectArr as! [CNContact])
            
            //            let path = VCard21String.write(toFile: filestr, andFileSuffix: "vcf")
//
            let filePath = (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()) + "/contacts.vcf"
            
            writeVCDCardsToFile(cards: cardStrArr, filePath: filePath)
            
            
            let fileManager = FileManager.default
            var fileSize : Int64 = 0
            do {
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if let fileSizes = attributes[FileAttributeKey.size] as? Int64 {
                    fileSize = fileSizes
                    print("文件大小为: \(fileSize) 字节")
                }
            } catch {
                print("获取文件属性失败: \(error)")
            }
            
            let dict =  ["itemCount":"\(selectArr.count)","fileSize":"\(fileSize)","fileName":"contacts.vcf","fileUrl":filePath]
            
            selectContacts?(dict)

//            exportContactAsVCard(aaaaa!)
            
        }else{
            AlertManager.showAlert(title: "提示".localized,message: "你还没有选择联系人".localized,cancelTitle: "取消".localized,cancelAction: {
                self.isBack = true
                self.dismiss(animated: true) {
                    self.fail?()
                }
//                self.navigationController?.popViewController(animated: true)
            },confirmTitle: "确定".localized,confirmAction:{
           
                
            })
        }

    }
    
    
    @IBAction func cancleAction(_ sender: UIButton) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        searchBarisBeginEditing(isBegin: false)
        isSearch = false
        self.contactTabble.reloadData()
        
    }
}
