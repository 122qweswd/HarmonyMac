//
//  MIFeedBackView.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/10.
//

import UIKit
import IBAnimatable
import Photos
import Toast
import IBAnimatable
import Network

class MIFeedBackView: MIBaseViewController, UITextViewDelegate {
    var backView: AnimatableView?
    var manger : ShareAPI?
    var closeAction:ClickBlockVoid?
    
    let newView = UIView()
    var takingPicture:UIImagePickerController!
    lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.chevronBackward, for: .normal)
        button.addClickClosure { [weak self] sender in
            self?.dismiss(animated: true)
        }
        return button
    }()
    lazy var finishButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.finish, for: .normal)
        return button
    }()
    var isUpdate : Bool = true
    var isError :  Bool = true
    var selectedTime: Date?
    let scView = UIScrollView()
    var placeLb = UILabel()
    var tipCountLb = UILabel()
    var textView : AnimatableTextView?
    
    var textFile : AnimatableTextField? =  AnimatableTextField()
    var textFileTime: UILabel = UILabel()
    
    var upStackView = UIStackView()

    lazy var upButton : UIButton = {
        let upButton = UIButton(type: .custom)
        upButton.setImage(UIImage.photoChoose, for: .normal)
        upButton.imageView?.contentMode = .scaleAspectFill  // 填充整个imageView
        upButton.contentHorizontalAlignment = .fill         // 水平填充
        upButton.contentVerticalAlignment = .fill           // 垂直填充
        upButton.addClickClosure { [weak self] _ in
            self?.selectImageAction()
        }
        return upButton
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NetworkMonitorFeedBack.shared.startMonitoring()
        self.view.backgroundColor = UIDevice.current.userInterfaceIdiom == .pad ? .white : .clear
        self.navigationController?.navigationBar.isHidden = true
        self.title = "意见反馈".localized
        
        // 创建主容器视图
        backView = AnimatableView()
        backView?.backgroundColor = "#F9F9F9".color
        backView?.cornerRadius = 32
        self.view.addSubview(backView ?? UIView())
        backView?.snp.makeConstraints {
            $0.horizontalEdges.bottom.equalToSuperview()
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.top.equalTo(0)
            } else {
                $0.top.equalTo(MISafeAreaTop)
            }
        }
        
//        self.backView?.addSubview(backButton)
        
        self.backView?.addSubview(finishButton)
        
        finishButton.snp.makeConstraints {
            $0.trailing.equalTo(phoneToPad(-16))
            $0.centerY.equalTo(self.navigationView?.backButton ?? 15)
        }
        
        finishButton.addClickClosure{ sender in
           // ShareAPI.shared().startLogging()
            self.submitAction()
        }

//        self.titleLabel.text = "意见反馈".localized
        
        self.backView?.addSubview(scView)
        scView.snp.makeConstraints {
            $0.horizontalEdges.equalToSuperview()
            $0.top.equalTo(phoneToPad(44 + 30))
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.bottom.equalToSuperview().offset(-96)
            }else{
                $0.bottom.equalToSuperview()
            }

        }
        //let newView = UIView()
        scView.addSubview(newView)
        // 设置初始约束
        newView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(self.view)
//            make.height.equalTo(800)
        }
        
        
        let questionfLb = UILabel()
        // 创建带红色星号的文本
        let questionText = "问题描述".localized
        let attributedString = NSMutableAttributedString(string: questionText + "*")

        // 设置整体文本样式
        attributedString.addAttributes([
            .font: pingFangSC(weight: .medium, size: 16),
            .foregroundColor: UIColor(hex: "#000000").withAlphaComponent(0.38) ?? .black
        ], range: NSRange(location: 0, length: attributedString.length))

        // 设置星号为红色
        attributedString.addAttributes([
            .foregroundColor: UIColor.red,
            .font:pingFangSC(weight: .medium, size: 20),
        ], range: NSRange(location: questionText.count, length: 1))

        questionfLb.attributedText = attributedString
        
        newView.addSubview(questionfLb)
        
        questionfLb.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(620)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(phoneToPad(30))
            }
            $0.top.equalToSuperview()
        }
        placeLb.text = "请尽量详细描述您的问题（不少于10字）".localized
        placeLb.font = pingFangSC(weight: .regular,size: 12)
        placeLb.textColor = "#000000".color.withAlphaComponent(0.65)
        placeLb.numberOfLines = 2
 
        
        textView = AnimatableTextView()
        textView?.text = ""
        textView?.placeholderText = "请尽量详细描述您的问题（不少于10字）".localized
        
        textView?.delegate = self
        textView?.textColor = .black
        textView?.font = .systemFont(ofSize: 20)
        textView?.contentInset =  UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        newView.addSubview(textView ?? AnimatableTextView())
        textView?.backgroundColor = .white
        textView?.cornerRadius = 22
        textView?.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(648)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.top.equalTo(questionfLb.snp.bottom).offset(8)
            $0.height.equalTo(120)
        }
        
        newView.addSubview(placeLb)
        placeLb.snp.makeConstraints { make in
            make.top.equalTo(textView?.snp.top ?? 0).offset(phoneToPad(20))
            make.leading.equalTo(textView?.snp.leading ?? 0).offset(phoneToPad(14))
            make.trailing.equalTo(textView?.snp.trailing ?? 0).offset(phoneToPad(-14))
        }
        
        tipCountLb.text = "0/30"
        tipCountLb.font = pingFangSC(weight: .regular,size: 12)
        tipCountLb.textColor = "#000000".color.withAlphaComponent(0.65)
        
        newView.addSubview(tipCountLb)
        
        tipCountLb.snp.makeConstraints { make in
            make.trailing.equalTo(textView?.snp.trailing ?? 0).offset(-14)
            make.bottom.equalTo(textView?.snp.bottom ?? 0).offset(-20)
        }
        
        let upLb = UILabel()
        upLb.text = "上传图片".localized
        upLb.font = pingFangSC(weight: .medium,size: 16)
        upLb.textColor = "#000000".color.withAlphaComponent(0.38)
        
        newView.addSubview(upLb)
        
        upLb.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(620)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(30)
            }
            $0.top.equalTo(self.textView?.snp.bottom ?? 0).offset(32)
        }
        
        
        let upView = AnimatableView()
        
        upView.backgroundColor = .white
        upView.cornerRadius = 22
        
        newView.addSubview(upView)
        
        upView.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(648)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.top.equalTo(upLb.snp.bottom).offset(8)
            $0.height.equalTo(122)
        }
            

        
        upStackView = UIStackView()
        upStackView.axis = .horizontal
        upStackView.alignment = .leading
        upStackView.distribution = .fillEqually
        upStackView.spacing = 5
        upView.addSubview(upStackView)
        upStackView.snp.makeConstraints {
            $0.leading.equalTo(10)
            $0.height.equalTo(82)
            $0.centerY.equalToSuperview()
        }
        

        upStackView.addArrangedSubview(upButton)
        
        upButton.snp.makeConstraints { make in
            make.height.width.equalTo(82)
        }
        
       

        let  bottomView = AnimatableView()
        
        bottomView.backgroundColor = .white
        bottomView.cornerRadius = 22
        
        newView.addSubview(bottomView)
        
        bottomView.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(648)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.top.equalTo(upView.snp.bottom).offset(32)
            $0.height.equalTo(180)
            if UIDevice.current.userInterfaceIdiom == .pad{
                $0.bottom.equalToSuperview()
            }else{
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
        
        
        let contentLb = UILabel()
        // 创建带红色星号的文本
        let contactText = "联系方式".localized
        let contactAttributedString = NSMutableAttributedString(string: contactText + "*")

        // 设置整体文本样式
        contactAttributedString.addAttributes([
            .font: pingFangSC(weight: .medium, size: 16),
            .foregroundColor: UIColor(hex: "#000000").withAlphaComponent(0.9) ?? .black
        ], range: NSRange(location: 0, length: contactAttributedString.length))

        // 设置星号为红色，并加大字号
        contactAttributedString.addAttributes([
            .foregroundColor: UIColor.red,
            .font:pingFangSC(weight: .medium, size: 20),
        ], range: NSRange(location: contactText.count, length: 1))

        contentLb.attributedText = contactAttributedString
        bottomView.addSubview(contentLb)
        
        contentLb.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(0)
            $0.height.equalTo(60)
        }
        
        
        textFile?.textAlignment = .right
        textFile?.placeholder = "请输入您的联系方式".localized
        textFile?.placeholderColor = "#000000".color.withAlphaComponent(0.38)
//        textFile?.keyboardType = .numberPad
        //textFile?.delegate = self
        textFile?.textColor = .black
        textFile?.font = pingFangSC(weight: .medium,size: 17)
        textFile?.paddingRight = 15
        

        bottomView.addSubview(textFile ?? AnimatableTextField())
        
        
        textFile?.snp.makeConstraints {
            $0.leading.equalTo(contentLb.snp.trailing).offset(10)
            $0.trailing.equalTo(-10)
            $0.top.equalTo(0)
            $0.height.equalTo(60)
        }
        
        let  line  = UIView()
        line.backgroundColor = .black.withAlpha(0.2)
        bottomView.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalTo(8)
            make.trailing.equalTo(-8)
            make.height.equalTo(0.5)
            make.top.equalTo(contentLb.snp.bottom)
        }
        
        
        let sendLb = UILabel()
        sendLb.text = "发送错误报告".localized
        sendLb.textColor = "#000000".color.withAlphaComponent(0.65)
        sendLb.font = pingFangSC(weight: .medium,size: 16)
        bottomView.addSubview(sendLb)
        
        sendLb.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(line.snp.bottom)
//            $0.bottom.equalToSuperview()
            $0.height.equalTo(60)
        }
        
        let mineSwitch = UISwitch()
        mineSwitch.isOn = isError
        mineSwitch.addTarget(self, action: #selector(switchClick(swi:)), for:UIControl.Event.valueChanged )//检测有值的变化
        mineSwitch.onTintColor = "#5C89F7".color
        bottomView.addSubview(mineSwitch)
        mineSwitch.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.centerY.equalTo(sendLb)
        }
         
        let  lineTwo  = UIView()
        lineTwo.backgroundColor = .black.withAlpha(0.2)
        bottomView.addSubview(lineTwo)
        lineTwo.snp.makeConstraints { make in
            make.leading.equalTo(8)
            make.trailing.equalTo(-8)
            make.height.equalTo(0.5)
            make.top.equalTo(sendLb.snp.bottom)
        }
        
        let timeButton = UIButton(type: .custom)
        timeButton.setTitle("发生时间*".localized, for: .normal)
        timeButton.setTitleColor(.white, for: .normal)
        timeButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
        timeButton.backgroundColor = UIColor(hex: "#5C89F7") // 蓝色背景
        timeButton.layer.cornerRadius = 8
        timeButton.addTarget(self, action: #selector(timeButtonAction), for: .touchUpInside)
        bottomView.addSubview(timeButton)
        timeButton.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(lineTwo.snp.bottom).offset(10)
            $0.height.equalTo(44)
            $0.bottom.equalToSuperview().offset(-10)
            $0.width.equalTo(100)
        }
        
        textFileTime.textAlignment = .right
        textFileTime.text = "" // 初始为空
        textFileTime.textColor = .black
        textFileTime.font = pingFangSC(weight: .medium, size: 17)
        bottomView.addSubview(textFileTime)
        
        textFileTime.snp.makeConstraints {
            $0.leading.equalTo(timeButton.snp.trailing).offset(10)
            $0.trailing.equalTo(-10)
            $0.top.equalTo(lineTwo.snp.bottom)
            $0.height.equalTo(60)
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            // 创建取消按钮
            let cancelButton = UIButton(type: .custom)
            cancelButton.setTitle("取消".localized, for: .normal)
            cancelButton.setTitleColor(.black, for: .normal)
            cancelButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
            cancelButton.backgroundColor = UIColor(hex: "#E5E5E5") // 灰色背景
            cancelButton.layer.cornerRadius = 24
            cancelButton.addTarget(self, action: #selector(cancelButtonAction), for: .touchUpInside)
            self.backView?.addSubview(cancelButton)

            // 创建保存按钮
            let saveButton = UIButton(type: .custom)
            saveButton.setTitle("保存".localized, for: .normal)
            saveButton.setTitleColor(.white, for: .normal)
            saveButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
            saveButton.backgroundColor = UIColor(hex: "#5C89F7") // 蓝色背景
            saveButton.layer.cornerRadius = 24
            saveButton.addTarget(self, action: #selector(naviRightItemClickAction), for: .touchUpInside)
            self.backView?.addSubview(saveButton)

            // 设置按钮约束
            cancelButton.snp.makeConstraints {
                $0.width.equalTo(128)
                $0.height.equalTo(48)
                $0.bottom.equalToSuperview().offset(-24)
                $0.trailing.equalTo(self.view.snp.centerX).offset(-10)
            }

            saveButton.snp.makeConstraints {
                $0.width.equalTo(128)
                $0.height.equalTo(48)
                $0.bottom.equalToSuperview().offset(-24)
                $0.leading.equalTo(self.view.snp.centerX).offset(10)
            }
        }
        
    }
    
    @objc func cancelButtonAction(_ sender: UIButton) {
        self.closeAction?()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.navigationController?.popViewController(animated: true)
        }
    }
    @objc private func timeButtonAction() {
        view.endEditing(true)
        let picker = DateTimePicker()
          picker.delegate = self
          picker.show(in: view)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.navigationView?.backButton?.setBackgroundImage(nil, for: .normal)
            self.finishButton.isHidden = true
          
        } else {
            self.finishButton.isHidden = true
            self.navigationView?.backButton?.setBackgroundImage(nil, for: .normal)
            if self.navigationView?.rightBarButtons()?.isEmpty ?? true {
                self.navigationView?.addRightBarButtonItemWithImage(UIImage.finish , UIImage.btnClose, target: self, action: #selector(naviRightItemClickAction(_:)))
            }
        }
        self.navigationView?.lineView.backgroundColor = .clear
    }
    @objc func naviRightItemClickAction(_ sender: UIButton) {
        self.submitAction()

    }
    //isRightCamera()
    @objc func switchClick(swi:UISwitch){
        
        isError = swi.isOn
        
        textFile?.resignFirstResponder()
        textView?.resignFirstResponder()
    }
    
    
    func textViewDidChange(_ textView: UITextView){
        
        
        if textView.text?.count == 0 {
            
            placeLb.text = "请尽量详细描述您的问题（不少于10字）".localized
            
        }else{
            placeLb.text = ""
        }
        
        
        tipCountLb.text = "\(30 - (textView.text?.count ?? 0))/30"
        if (textView.text?.count ?? 0) > 30 {
            textView.text = String(textView.text?.prefix(30) ?? "")
            tipCountLb.text = "0/30"
        }
        
        
    }

}


// MARK: - 点击事件
extension MIFeedBackView{
    func submitAction(){
        if !NetworkMonitorFeedBack.shared.isReachable {
            self.view.pickerMakeToast("请检查网络连接".localized, duration: 2.0,point: self.view.center, title: nil, image: nil) { didTap in
            }
            return
        }
        if textView?.text?.count ?? 0 < 10 {
            self.view.pickerMakeToast("请填写10字以上的问题描述".localized, duration: 2.0,point: self.view.center, title: nil, image: nil) { didTap in
                
            }
            return
        }
        if textFile?.text?.count == 0 {
            self.view.pickerMakeToast("请填写联系方式".localized, duration: 2.0,point: self.view.center, title: nil, image: nil) { didTap in
                
            }
            return
        }
        if textFileTime.text?.count == 0 {
            self.view.pickerMakeToast("请选择发生时间".localized, duration: 2.0,point: self.view.center, title: nil, image: nil) { didTap in
                
            }
            return
        }
        if(isUpdate){
            isUpdate=false
            var picSpi: String=""
            var logSpi: String=""
            let allImages = upStackView.getAllImages()
            let upLoader = OBSUploader()
            Task {
                do {
                    self.view.makeToast("提交中，请保持在当前页面，不要退出后台".localized, position: ToastPosition.center)
                    let dateStr = textFileTime.text ?? ""
                    manger = ShareAPI.shared()
                    let filePath=self.manger?.getUploadLogFile(UserDefaults.standard.string(forKey: "appleUserIDKey") ?? "",ts: dateStr)
                    if((filePath?.isEmpty) != nil)
                    {
                        var uuid=UUID().uuidString
                        let response = try await upLoader.uploadFile(
                            objectKey: uuid+".log",
                            filePath: String(filePath!),
                        )
                        if(response == 200)
                        {
                            logSpi="https://"+upLoader.bucketName+"."+upLoader.endpoint+"/"+uuid+".log"
                        }
                    }
                    for item in allImages
                    {
                        var uuid=UUID().uuidString
                        let response = try await upLoader.uploadFile(
                            objectKey: uuid+".jpg",
                            uiImageData: item,
                        )
                        if(response == 200)
                        {
                            picSpi=picSpi+"[https://"+upLoader.bucketName+"."+upLoader.endpoint+"/"+uuid+".jpg],"
                        }
                    }
                    
                    var picStr: String=""
                    if(picSpi.count>0)
                    {
                        picStr=String(picSpi.prefix(picSpi.count-1))
                    }else{
                        picStr="[],[],[]"
                    }
                    let feedbackUploader=FeedbackUploader()
                    feedbackUploader.upload(contact: textFile?.text ?? "",des: textView?.text ?? "",pic: picStr,report: String(isError),time: textFileTime.text ?? "/",log: logSpi,appleUserID: UserDefaults.standard.string(forKey: "appleUserIDKey") ?? "")
                    self.view.hideToast()
                    self.view.makeToast("提交成功".localized, position: ToastPosition.center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0){
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            self.navigationController?.popViewController(animated: true)
                        } else {
                            self.dismiss(animated: true)
                        }
                    }
                } catch {
                    self.view.hideToast()
                    self.view.makeToast("提交失败请重试".localized, position: ToastPosition.center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.view.hideToast()
                    }
                }
                isUpdate=true
            }
        }
        
    }
    func selectImageAction()  {
        
        let alert = UIAlertController(title: "选择要上传的文件".localized,message: nil, preferredStyle: .actionSheet)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: 0, y: ksUIScreenH-60, width: ksUIScreenW, height: 50)
            }
        }
           let cancelAction = UIAlertAction(title: "取消".localized, style: .cancel) { [weak self] _ in
               
               guard let _ = self else { return  }
               
           }
           alert.addAction(cancelAction)
           
        if #available(iOS 13.0, *) {
            DispatchQueue.main.async {
                alert.overrideUserInterfaceStyle = .light
            }
        }
           
           
           //打开相机相册
         
           
           let assetsLibraryAction = UIAlertAction(title: "从手机相册选择".localized, style: .default) { [weak self] _ in
               self?.albumAction()
       
           }
           
        let filesAction = UIAlertAction(title: MILocalized("拍照".localized), style: .default) { [weak self] _ in
               self?.cameraButtonClick()
           }
      
           
           alert.addAction(assetsLibraryAction)
           
           alert.addAction(filesAction)
           
        self.present(alert, animated: true, completion: nil)
        
    }
    
 func cameraButtonClick() {
        //去拍照或者去相册选择图片
        
    
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    // 相机权限已授予
                    // 可以在这里启动相机等操作
                    self.showPickerController(type: .camera)
                } else {
                    // 相机权限被拒绝
                    self.showEventsAcessDeniedAlertPho()
                }
            }
        case .authorized:
            // 相机权限已授予
            // 可以在这里启动相机等操作
            self.showPickerController(type: .camera)
        case .denied, .restricted:
            // 相机权限被拒绝或受限制
            showEventsAcessDeniedAlertPho()
        @unknown default:
            showEventsAcessDeniedAlertPho()
        }

    }
    
    
    func showPickerController(type:UIImagePickerController.SourceType){
        
        DispatchQueue.main.async {
       
            self.takingPicture =  UIImagePickerController.init()
        
            self.takingPicture.sourceType = type
        
        //是否截取，设置为true在获取图片后可以将其截取成正方形
            self.takingPicture.allowsEditing = false
            //self.takingPicture.
            self.takingPicture.delegate = self
            self.present(self.takingPicture, animated: true, completion: nil)
        }
    }
  
    
   func albumAction() {
       // let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .notDetermined:
            
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    self.showPickerController(type: .photoLibrary)
                } else {
                    self.showEventsAcessDeniedAlertPic()
                }
            }
        case .authorized:
            // 相机权限已授予
            // 可以在这里启动相机等操作
            self.showPickerController(type: .photoLibrary)
        case .denied, .restricted,.limited:
            // 相机权限被拒绝或受限制
            showEventsAcessDeniedAlertPic()
    
        @unknown default:
            showEventsAcessDeniedAlertPic()
        }
        
   
    }
    
    func showEventsAcessDeniedAlertPho() {
        DispatchQueue.main.async {
            AlertManager.showAlert(title: "无法访问相机".localized, message: "没有获得相机访问权限，请在设置中允许访问相机".localized, cancelTitle: "取消".localized, cancelAction: {
                
            }, confirmTitle: "开启权限".localized) {
                if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    func showEventsAcessDeniedAlertPic() {
        DispatchQueue.main.async {
            AlertManager.showAlert(title: "无法访问相册".localized, message: "没有获得相册访问权限，请在设置中允许访问相册".localized, cancelTitle: "取消".localized, cancelAction: {
                
            }, confirmTitle: "开启权限".localized) {
                if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}

extension MIFeedBackView:  UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    // 相机权限
    func isRightCamera() -> Bool {
        
        let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        return authStatus != .restricted && authStatus != .denied
    }
    
    //拍照或是相册选择返回的图片
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        takingPicture.dismiss(animated: true, completion: nil)
        if(takingPicture.allowsEditing == false){
            
            guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return  }
            
//            let MaxStickerFileSize: Int = 800 * 1024
//            
//            if let imageData = image?.compressImageMid(maxLength: MaxStickerFileSize) {
//            
//                upLoadImage(imageData: imageData)
//            }
            
            selectImageResult(selectImg: image)
        }
    }
    
    
    func selectImageResult(selectImg:UIImage) {
        
        let fiImg = UIImageView()
        fiImg.image = selectImg
        fiImg.layer.cornerRadius = 20
        fiImg.clipsToBounds = true
        fiImg.isUserInteractionEnabled = true
        fiImg.contentMode = .scaleAspectFill
        
        upStackView.insertArrangedSubview(fiImg, at: upStackView.subviews.count-1)
       
     
        fiImg.snp.makeConstraints { make in
            make.height.width.equalTo(82)
        }
        let delectbtn = UIButton(type:.custom)
        delectbtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        delectbtn.tintColor = UIColor.red
        delectbtn.backgroundColor = UIColor.white
        delectbtn.layer.cornerRadius = 10
        fiImg.addSubview(delectbtn)
        delectbtn.addClickClosure { sender in
            self.upStackView.removeArrangedSubview(fiImg)
            fiImg.removeFromSuperview()
            
            if self.upStackView.subviews.count < 3 {
                self.upStackView.addArrangedSubview(self.upButton)
            }
        }
        delectbtn.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(3)
            make.trailing.equalToSuperview().offset(-3)
            make.width.height.equalTo(20)
        }
        
        if upStackView.subviews.count >= 4 {
            upStackView.removeArrangedSubview(upButton)
            upButton.removeFromSuperview()
        }

    }
    func upLoadImage(imageData:Data){
        
//        SVProgressHUD.show()
//        
//        //// augic 图片来源:1相册 2:拍照上传
//        ///productId, // 产品id
//        ///"yearatory" :
//        //isFace, //10:人脸自拍, 11身份证正面
//        // cardKind,  //卡类型 UMID/SSS/TIN/PASSPORT/DRIVINGLICENSE/PRC/POSTAL/Voter/PhilHealth
//       
//        FileUploadTool.load(imageData: imageData, augic:  takingPicture.sourceType == .camera ? "2" : "1", productId: productId, isFace: isFace, cardKind: cardKind) { [weak self] code, msg, data, json in
//           let venimost =   Venimost.deserialize(from: data as? Dictionary<String, Any>)
//            SVProgressHUD.dismiss()
//            self?.identifyBlockVoid?(venimost)
//            self?.dismissView(true)
//        } failure: { error in
//            
//            SVProgressHUD.dismiss()
//        
//            self.makeToast(error.stringMsg(), duration: 2.0,point: self.center, title: nil, image: nil) { didTap in
//            }
//            
//        }
    }
}

extension UIImage {
    //二分压缩法
    func compressImageMid(maxLength: Int) -> Data? {
        var compression: CGFloat = 1
        
        guard var data = self.pngData() else { return nil }
        if data.count < maxLength {
            return data
        }
        print("压缩前kb", data.count / 1024, "KB")
        var max: CGFloat = 1
        var min: CGFloat = 0
        for _ in 0..<6 {
            compression = (max + min) / 2
            data = self.jpegData(compressionQuality: compression)!
            
            if CGFloat(data.count) < CGFloat(maxLength) * 0.9 {
                min = compression
            } else if data.count > maxLength {
                max = compression
            } else {
                break
            }
        }
        
        
    //        var resultImage: UIImage = UIImage(data: data)!
        if data.count < maxLength {
            return data
        }
        return data
    }
}
extension UIStackView {
    /// 获取stackView中所有UIImage对象
    func getAllImages() -> [UIImage] {
        var images = [UIImage]()
        
        // 遍历所有排列的子视图
        for arrangedSubview in arrangedSubviews {
            // 如果是UIImageView且包含图片
            if let imageView = arrangedSubview as? UIImageView,
               let image = imageView.image {
                images.append(image)
            }
        }
        return images
    }
}

extension MIFeedBackView: DateTimePickerDelegate {
    // 确认选择
    func dateTimePicker(_ picker: DateTimePicker, didSelectDate date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")


        textFileTime.text = formatter.string(from: date)
    }
    // 取消选择
    func dateTimePickerDidCancel(_ picker: DateTimePicker) {


    }
}
class NetworkMonitorFeedBack {
    static let shared = NetworkMonitorFeedBack()
    private let monitor: NWPathMonitor
    private var status: NWPath.Status = .requiresConnection
    var isReachable: Bool { status == .satisfied }

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.status = path.status
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
