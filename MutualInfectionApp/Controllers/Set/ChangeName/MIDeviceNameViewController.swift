//
//  MIDeviceNameViewController.swift
//  MutualInfection
//
//  Created by apple on 2025/9/2.
//

import UIKit
import IBAnimatable
import Foundation

class MIDeviceNameViewController: MIEffectViewVC, UIImagePickerControllerDelegate & UINavigationControllerDelegate {

    private let maxTextLength = 12
    private var isTruncating = false
    
    var chageNameClick: ((String) -> Void)?
    var chageAvatarClick: ((_ image: UIImage) -> Void)?
    var deviceName : String?
    var userAvatar : UIImage?
    // 确认修改按钮
    private let confirmButton = UIButton(type: .custom)
    // 内容容器
    private let contentContainer = UIView()
    // 设备图标
    private let deviceIcon = UIImageView()
    // 设备当前名称
    private let deviceNameLb = UILabel()
    // 名称
    private let nameLb = UILabel()
    // 名称输入框
    private let nameTextField = UITextField()
    // 恢复默认按钮
    private let getDefaultNameButton = UIButton(type: .custom)
    // 输入框下划线
    private let textLabelBottomLine = UIView()
    // 提示
    private let desLb = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        closeButton.setImage(UIImage.btnClose, for: .normal)
        
        titleLabel.text = "修改名称".localized
        titleLabel.font = pingFangSC(weight: .medium, size: 17)
        
        //初始化UI
        setupUI()
        
        //添加事件处理
        setupEventHandles()
    }
    
    private func setupUI() {
        // 添加确认按钮
        view.addSubview(confirmButton)
        confirmButton.setImage(UIImage.finish, for: .normal)
        confirmButton.snp.makeConstraints {
            make in
            make.trailing.equalTo(phoneToPad(-16))
            make.top.equalTo(closeButton.snp.top).offset(0)
            make.bottom.equalTo(closeButton.snp.bottom).offset(0)
        }
        
        // 添加容器
        view.addSubview(contentContainer)
        contentContainer.backgroundColor = .white
        contentContainer.layer.cornerRadius = 32
        contentContainer.snp.makeConstraints {
            make in
            make.leading.equalTo(phoneToPad(16))
            make.trailing.equalTo(phoneToPad(-16))
            make.top.equalTo(titleLabel.snp.bottom).offset(phoneToPad(41))
        }
        
        // 添加设备图标
        contentContainer.addSubview(deviceIcon)
        deviceIcon.image = userAvatar
        deviceIcon.contentMode = .scaleAspectFit
        deviceIcon.layer.cornerRadius = 40
        deviceIcon.layer.masksToBounds = true
        deviceIcon.snp.makeConstraints {
            make in
            make.centerX.equalToSuperview()
            make.top.equalTo(phoneToPad(30))
            make.width.height.equalTo(phoneToPad(80))
        }
        
        // 添加设备名称
        contentContainer.addSubview(deviceNameLb)
        deviceNameLb.text = deviceName
        deviceNameLb.textColor = .black
        deviceNameLb.font = pingFangSC(weight: .medium, size: 17)
        deviceNameLb.snp.makeConstraints {
            make in
            make.centerX.equalToSuperview()
            make.top.equalTo(deviceIcon.snp.bottom).offset(phoneToPad(8))
        }
        
        // 添加名称标签
//        contentContainer.addSubview(nameLb)
//        nameLb.text = "名称".localized
//        nameLb.textColor = .black
//        nameLb.font = pingFangSC(weight: .medium, size: 17)
//        nameLb.snp.makeConstraints {
//            make in
//            make.leading.equalToSuperview().offset(phoneToPad(20))
//            make.top.equalTo(deviceNameLb.snp.bottom).offset(phoneToPad(32))
//            make.width.lessThanOrEqualTo(80)
//        }
        
        // 添加名称输入框
        contentContainer.addSubview(nameTextField)
        nameTextField.text = deviceName
        nameTextField.placeholder = "输入要修改的名称".localized
        nameTextField.delegate = self
        nameTextField.textColor = .black
        nameTextField.font = pingFangSC(weight: .medium, size: 17)
        nameTextField.snp.makeConstraints {
            make in
            make.leading.equalToSuperview().offset(phoneToPad(20))
            make.trailing.equalToSuperview().offset(phoneToPad(-20))
            make.top.equalTo(deviceNameLb.snp.bottom).offset(phoneToPad(32))
            make.height.equalTo(phoneToPad(40))
        }
        
        // 添加恢复默认按钮
        contentContainer.addSubview(getDefaultNameButton)
        getDefaultNameButton.setTitle("恢复默认".localized, for: .normal)
        getDefaultNameButton.setTitleColor("#336FFF".color, for: .normal)
        getDefaultNameButton.titleLabel?.font = pingFangSC(weight: .regular, size: 13)
        getDefaultNameButton.snp.makeConstraints {
            make in
            make.trailing.equalToSuperview().offset(phoneToPad(-28))
            make.top.equalTo(deviceNameLb.snp.bottom).offset(phoneToPad(36))
            make.width.lessThanOrEqualTo(phoneToPad(100))
        }
        
        //添加输入框下划线到容器中
        contentContainer.addSubview(textLabelBottomLine)
        textLabelBottomLine.backgroundColor = UIColor.black.withAlpha(0.38)
        textLabelBottomLine.snp.makeConstraints {
            make in
            make.leading.equalToSuperview().offset(phoneToPad(20))
            make.trailing.equalToSuperview().offset(phoneToPad(-20))
            make.top.equalTo(nameTextField.snp.bottom).offset(phoneToPad(2))
            make.height.equalTo(phoneToPad(0.5))
        }
        
        // 添加字符限制描述
        contentContainer.addSubview(desLb)
        desLb.text = "2-12位字符，可包含英文字母、数字、汉字，该名称将在对方的搜索页面展示。".localized
        desLb.numberOfLines = 0
        desLb.lineBreakMode = .byWordWrapping
        desLb.textColor = UIColor.black.withAlpha(0.65)
        desLb.font = pingFangSC(weight: .regular, size: 13)
        desLb.snp.makeConstraints {
            make in
            make.leading.equalToSuperview().offset(phoneToPad(20))
            make.trailing.equalToSuperview().offset(phoneToPad(-20))
            make.top.equalTo(textLabelBottomLine.snp.bottom).offset(phoneToPad(12))
            make.bottom.equalTo(phoneToPad(-16))
        }
    }
    
    private func setupEventHandles() {
        // 确认按钮点击事件
        confirmButton.addTarget(self, action: #selector(rightAction), for: .touchUpInside)
        // 监听输入框变化
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        // 恢复默认按钮点击事件
        getDefaultNameButton.addTarget(self, action: #selector(handleDefaultNameButtonClick), for: .touchUpInside)
        // 设备图标点击事件
//        deviceIcon.isUserInteractionEnabled = true
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(deviceIconTapped))
//        deviceIcon.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.clear
    }
    
    @objc private func handleDefaultNameButtonClick() {
        nameTextField.text = UIDevice.current.deviceName
        self.chageNameClick?(UIDevice.current.deviceName)
    }
    
    @IBAction func rightAction(_ sender: UIButton) {

        //修改系统设备名称
        nameTextField.resignFirstResponder()

        if (nameTextField.text?.count ?? 0) > 0  {

            //判断是否为空
            let isEmptyNameText = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isEmptyNameText ?? true {
                AlertManager.showAlert(
                    title: "提示".localized,
                    message: "设备名称不能为空".localized,
                    confirmTitle: "确定".localized,
                    confirmAction: {}
                )
                return
            }
            //判断是否符合字节长度
            let deviceNameText = nameTextField.text?.trimmingWhitespace()
            let isValid = isValidInput(deviceNameText ?? "")
            if(isValid == false){
                AlertManager.showAlert(title: "提示".localized,message: "请输入符合要求的文本（2-12位字符，可包含英文字母、数字、汉字）".localized,confirmTitle: "确定".localized,confirmAction:{
                })
            }else {
                // 符合就去修改设备名称
                self.chageNameClick?(deviceNameText ?? "")
                //修改完成 执行
                self.dismiss(animated: true)
            }
        }else{
            // 提示请输入需要修改的设备名称
            AlertManager.showAlert(title: "提示".localized,message: "请输入你要修改的名称".localized,cancelTitle: "取消".localized,cancelAction: {


            },confirmTitle: "确定".localized,confirmAction:{


            })
        }
        
 
        
    }
    
    // 处理设备图标点击事件，打开图片选择器
    @objc private func deviceIconTapped() {
        // 确保设备支持图片库访问
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .photoLibrary
//            imagePicker.mediaTypes = ["public.image"]
            imagePicker.delegate = self
            imagePicker.allowsEditing = true // 允许用户编辑图片
            present(imagePicker, animated: true, completion: nil)
        } else {
            // 如果不支持图片库，显示提示
            let alert = UIAlertController(title: "提示".localized,
                                          message: "无法访问相册，请检查设备权限设置。".localized,
                                         preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定".localized, style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    
    
    

}


extension MIDeviceNameViewController: UITextFieldDelegate{
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 临时候选状态（如中文拼音未确认）：不限制，直接允许
        if textField.markedTextRange != nil {
            return true
        }
        
        // 检查输入字符合法性（非法字符直接阻止）
        if !string.isLetterNumberAndChinese() {
            return false
        }
        
        // 获取当前文本
        let currentText = textField.text ?? ""
        let currentTextAsNSString = currentText as NSString
        
        // 计算替换后的文本
        let textAfterReplacement = currentTextAsNSString.replacingCharacters(in: range, with: string)
        
        // 未超出限制：正常允许
        if textAfterReplacement.count <= maxTextLength {
            return true
        }
        
        // 超出限制：截断到最大长度并手动更新
        let replacedText = currentTextAsNSString.replacingCharacters(in: range, with: string) as NSString
        let truncatedText = replacedText.substring(to: maxTextLength)
        textField.text = truncatedText
        
        // 触发文本变化事件，确保UI更新
        textField.sendActions(for: .editingChanged)
        
        return false
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        // 防止递归调用
        guard !isTruncating else { return }
        
        // 临时候选状态不处理
        if textField.markedTextRange != nil {
            return
        }
        
        guard let text = textField.text, text.count > maxTextLength else {
            return
        }
        // 超出限制，进行截断处理
        isTruncating = true
        // 截断到最大长度
        textField.text = String(text.prefix(maxTextLength))
        
        // 恢复标志位
        isTruncating = false
    }
    
    //键盘回车事件
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // 隐藏键盘
        textField.resignFirstResponder()
        return true
    }
    
    // UIImagePickerControllerDelegate 方法：处理选择的图片
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // 隐藏图片选择器
        picker.dismiss(animated: true) {[weak self] in
            guard let self = self else{
                return
            }
            // 尝试获取编辑后的图片，如果没有则获取原始图片
            if let editedImage = info[.editedImage] as? UIImage {
                deviceIcon.image = editedImage
                deviceIcon.layer.cornerRadius = 40
                deviceIcon.layer.masksToBounds = true
                self.chageAvatarClick?(editedImage)
                if let topVC = MIGetTopViewController() {
                    topVC.view.pickerMakeToast("修改成功".localized, duration: 2.0, point: topVC.view.center, title: nil, image: nil) { didTap in
                    }
                }
            } else if let originalImage = info[.originalImage] as? UIImage {
                deviceIcon.image = originalImage
                deviceIcon.layer.cornerRadius = 40
                deviceIcon.layer.masksToBounds = true
            }
        }
    }

    // UIImagePickerControllerDelegate 方法：用户取消选择
    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // 隐藏图片选择器
        picker.dismiss(animated: true, completion: nil)
    }
}
