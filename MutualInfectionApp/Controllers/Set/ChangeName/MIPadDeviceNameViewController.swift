//
//  MIPadDeviceNameViewController.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/14.
//

import UIKit
import IBAnimatable
import Foundation

class MIPadDeviceNameViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {

    private let maxTextLength = 12
    private var isTruncating = false
    
    var chageNameClick: ((String) -> Void)?
    var chageAvatarClick: ((_ image: UIImage) -> Void)?
    var deviceName : String?
    var userAvatar : UIImage?
    // 确认修改按钮
    private let saveButton = UIButton(type: .custom)
    // 取消按钮
    private let cancelButton = UIButton(type: .custom)
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
    // 提示
    private let desLb = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //初始化UI
        view.backgroundColor = .white
        setupUI()
        setupKeyboardObservers()
        
        //添加事件处理
        setupEventHandles()
    }
    
    private func setupUI() {
        
        // 添加容器
        view.addSubview(contentContainer)
        contentContainer.backgroundColor = .white
        contentContainer.layer.cornerRadius = 32
        contentContainer.snp.makeConstraints {
            make in
            make.centerX.equalToSuperview()
            make.top.equalTo(210)
            make.width.equalTo(300)
        }
        
        // 添加设备图标
        contentContainer.addSubview(deviceIcon)
        deviceIcon.image = userAvatar
        deviceIcon.contentMode = .scaleAspectFill
        deviceIcon.layer.cornerRadius = 40
        deviceIcon.layer.masksToBounds = true
        deviceIcon.snp.makeConstraints {
            make in
            make.centerX.equalToSuperview()
            make.top.equalTo(54)
            make.width.equalTo(80)
            make.height.equalTo(80)
        }
        
        // 添加设备名称
        contentContainer.addSubview(deviceNameLb)
        deviceNameLb.text = deviceName
        deviceNameLb.textColor = .black
        deviceNameLb.font = pingFangSC(weight: .medium, size: 17)
        deviceNameLb.snp.makeConstraints {
            make in
            make.centerX.equalToSuperview()
            make.top.equalTo(deviceIcon.snp.bottom).offset(8)
        }
        
        // 添加名称输入框
        contentContainer.addSubview(nameTextField)
        nameTextField.text = deviceName
        nameTextField.placeholder = "输入名称".localized
        nameTextField.delegate = self
        nameTextField.textColor = .black
        nameTextField.backgroundColor = UIColor(red: 120/255, green: 120/255, blue: 128/255, alpha: 0.16)
        nameTextField.layer.cornerRadius = 24
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        nameTextField.leftView = paddingView
        nameTextField.leftViewMode = .always
        nameTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        nameTextField.rightViewMode = .always
        nameTextField.font = pingFangSC(weight: .medium, size: 17)
        nameTextField.clearButtonMode = .whileEditing
        nameTextField.borderStyle = .none
        nameTextField.snp.makeConstraints {
            make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(deviceNameLb.snp.bottom).offset(10)
            make.height.equalTo(52)
        }
        
        // 添加恢复默认按钮
        contentContainer.addSubview(getDefaultNameButton)
        getDefaultNameButton.setTitle("恢复默认".localized, for: .normal)
        getDefaultNameButton.setTitleColor("#336FFF".color, for: .normal)
        getDefaultNameButton.titleLabel?.font = pingFangSC(weight: .regular, size: 13)
        getDefaultNameButton.snp.makeConstraints {
            make in
            make.trailing.equalToSuperview().offset(phoneToPad(-24))
            make.top.equalTo(deviceNameLb.snp.bottom).offset(phoneToPad(14))
            make.width.lessThanOrEqualTo(phoneToPad(100))
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
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(nameTextField.snp.bottom).offset(10)
        }
        
        contentContainer.addSubview(cancelButton)
        cancelButton.setTitle("取消".localized, for: .normal)
        cancelButton.setTitleColor(.black, for: .normal)
        cancelButton.titleLabel?.font = pingFangSC(weight: .medium, size: 17)
        cancelButton.backgroundColor = UIColor(red: 120/255, green: 120/255, blue: 128/255, alpha: 0.16)
        cancelButton.layer.cornerRadius = 24
        cancelButton.snp.makeConstraints {
            make in
            make.leading.equalToSuperview().offset(14)
            make.top.equalTo(desLb.snp.bottom).offset(10)
            make.bottom.equalTo(-14)
            make.width.equalTo(128)
            make.height.equalTo(48)
        }
        
        contentContainer.addSubview(saveButton)
        saveButton.setTitle("保存".localized, for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = pingFangSC(weight: .medium, size: 17)
        saveButton.backgroundColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1)
        saveButton.layer.cornerRadius = 24
        saveButton.snp.makeConstraints {
            make in
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(desLb.snp.bottom).offset(10)
            make.bottom.equalTo(-14)
            make.width.equalTo(128)
            make.height.equalTo(48)
        }
    }
    
    private func setupEventHandles() {
        // 确认按钮点击事件
        saveButton.addTarget(self, action: #selector(rightAction), for: .touchUpInside)
        // 确认按钮点击事件
        cancelButton.addTarget(self, action: #selector(leftAction), for: .touchUpInside)
        //监听输入框变化
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
    
    @IBAction func leftAction(_ sender: UIButton) {
        self.dismiss(animated: true)
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
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        let screenHeight = UIScreen.main.bounds.height
        let containerMaxY = contentContainer.frame.maxY
        let bottomSpace = screenHeight - containerMaxY
        
        // 如果需要上移才调整位置
        if keyboardHeight > bottomSpace {
            UIView.animate(withDuration: 0.3) {
                self.contentContainer.snp.remakeConstraints {
                    make in
                    make.centerX.equalToSuperview()
                    make.top.equalTo(139)
                    make.width.equalTo(300)
                }
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.contentContainer.snp.remakeConstraints {
                make in
                make.centerX.equalToSuperview()
                make.top.equalTo(210)
                make.width.equalTo(300)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}


extension MIPadDeviceNameViewController: UITextFieldDelegate{
    
    
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
                    let offsetY = 219.0
                    let customPoint = CGPoint(x: topVC.view.center.x, y: offsetY)
                    topVC.view.pickerMakeToast("修改成功".localized, duration: 2.0, point: customPoint, title: nil, image: nil) { didTap in
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

