//
//  PickerConfigurationViewController.swift
//  Example
//
//  Created by Slience on 2021/3/16.
//

import UIKit
import XXPhotoPicker

class PickerConfigurationViewController: UITableViewController {
    
    var config: PickerConfiguration = .init()
    var didDoneHandler: ((PickerConfiguration, Bool) -> Void)?
    var showOpenPickerButton: Bool = true
    
    var isSplitAction: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Picker"
        loadFonts()
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.register(ConfigurationViewCell.self, forCellReuseIdentifier: ConfigurationViewCell.reuseIdentifier)
        tableView.tableFooterView = UIView(frame: .zero)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: showOpenPickerButton ? "打开选择器" : "确定",
            style: .done,
            target: self,
            action: #selector(openPickerController)
        )
        #if targetEnvironment(simulator)
        self.config.selectOptions = [.photo, .gifPhoto, .livePhoto, .video]
        #else
        self.config.selectOptions = [.photo, .gifPhoto, .livePhoto, .HDRPhoto, .video]
        #endif
    }
    
    @objc func openPickerController() {
        if showOpenPickerButton {
            if isSplitAction {
                let picker = PhotoPickerController(splitPicker: config)
                picker.pickerDelegate = self
                picker.autoDismiss = false
                let split = PhotoSplitViewController(picker: picker)
                present(split, animated: true, completion: nil)
                return
            }
            #if OCEXAMPLE
            if #available(iOS 13.0.0, *) {
                Task {
                    do {
                        config.isAutoBack = false
                        let controller = try await PhotoPickerController.show(config)
                        let result = try await controller.picker()
                        let pickerResultVC = PickerResultViewController()
                        pickerResultVC.config = config
                        pickerResultVC.selectedAssets = result.photoAssets
                        pickerResultVC.isOriginal = result.isOriginal
                        navigationController?.pushViewController(pickerResultVC, animated: false)
                        controller.dismiss(true)
                    } catch {
                        print(error)
                    }
                }
            } else {
                if UIDevice.isPad {
                    let picker = PhotoPickerController(splitPicker: config)
                    picker.pickerDelegate = self
                    picker.autoDismiss = false
                    let split = PhotoSplitViewController(picker: picker)
                    present(split, animated: true, completion: nil)
                }else {
                    let vc = PhotoPickerController.init(config: config)
                    vc.pickerDelegate = self
                    vc.autoDismiss = false
                    present(vc, animated: true, completion: nil)
                }
            }
#endif
        }else {
            didDoneHandler?(config, isSplitAction)
            dismiss(animated: true, completion: nil)
        }
    }
    
    func loadFonts() {
        var masks: [EditorConfiguration.CropSize.MaskType] = []
        if let path = Bundle.main.path(forResource: "love", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            masks.append(.image(image))
        }
        if let path = Bundle.main.path(forResource: "love_text", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            masks.append(.image(image))
        }
        if let path = Bundle.main.path(forResource: "stars", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            masks.append(.image(image))
        }
        if let path = Bundle.main.path(forResource: "text", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            masks.append(.image(image))
        }
        if let path = Bundle.main.path(forResource: "qiy", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            masks.append(.image(image))
        }
        if let path = Bundle.main.path(forResource: "portrait", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            masks.append(.image(image))
        }
        for family in UIFont.familyNames {
            if UIFont.fontNames(forFamilyName: family).contains("AppleSymbols") {
                masks.append(.text("🀚", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("�", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("🜯", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("♚", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬♞", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬‬♜", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬‬♨", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬‬☚", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬‬☛", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬‬☁", .init(name: "AppleSymbols", size: 55)!))
                masks.append(.text("‬‬‬▚", .init(name: "AppleSymbols", size: 55)!))
                break
            }
        }
        masks.append(.text("‬‬‬Swift", UIFont.boldSystemFont(ofSize: 50)))
        masks.append(.text("‬‬‬XXPhotoPicker", UIFont.boldSystemFont(ofSize: 50)))
        config.editor.cropSize.maskList = masks
    }
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if !showOpenPickerButton {
            return UIDevice.isPad ? 2 : 3
        }
        return ConfigSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !showOpenPickerButton {
            if !UIDevice.isPad {
                if section == 0 {
                    return 1
                }else {
                    return ConfigSection.allCases[section].allRowCase.count
                }
            }else {
                return ConfigSection.allCases[section + 1].allRowCase.count
            }
        }
        if UIDevice.isPad, section == 0 {
            return 1
        }
        return ConfigSection.allCases[section].allRowCase.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConfigurationViewCell.reuseIdentifier,
            for: indexPath
        ) as! ConfigurationViewCell
        let rowType: ConfigRowTypeRule
        if !showOpenPickerButton {
            if !UIDevice.isPad {
                if indexPath.section == 0 {
                    rowType = ConfigSection.allCases[indexPath.section].allRowCase[1]
                }else {
                    rowType = ConfigSection.allCases[indexPath.section].allRowCase[indexPath.row]
                }
            }else {
                rowType = ConfigSection.allCases[indexPath.section + 1].allRowCase[indexPath.row]
            }
        }else {
            rowType = ConfigSection.allCases[indexPath.section].allRowCase[indexPath.row]
        }
        
        cell.setupData(rowType, getRowContent(rowType))
        return cell
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        54
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let rowType: ConfigRowTypeRule
        if !showOpenPickerButton {
            if !UIDevice.isPad {
                if indexPath.section == 0 {
                    rowType = ConfigSection.allCases[indexPath.section].allRowCase[1]
                }else {
                    rowType = ConfigSection.allCases[indexPath.section].allRowCase[indexPath.row]
                }
            }else {
                rowType = ConfigSection.allCases[indexPath.section + 1].allRowCase[indexPath.row]
            }
        }else {
            rowType = ConfigSection.allCases[indexPath.section].allRowCase[indexPath.row]
        }
        rowType.getFunction(self)(indexPath)
    }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        40
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !showOpenPickerButton {
            if UIDevice.isPad {
                return ConfigSection.allCases[section + 1].title
            }
        }
        return ConfigSection.allCases[section].title
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if showOpenPickerButton {
            tableView.reloadData()
        }
    }
}
extension PickerConfigurationViewController: PhotoPickerControllerDelegate {
    func pickerController(_ pickerController: PhotoPickerController, didFinishSelection result: PickerResult) {
        #if OCEXAMPLE
        pickerController.dismiss(true) {
            let pickerResultVC = PickerResultViewController.init()
            pickerResultVC.config = pickerController.config
            pickerResultVC.selectedAssets = result.photoAssets
            pickerResultVC.isOriginal = result.isOriginal
            self.navigationController?.pushViewController(pickerResultVC, animated: true)
        }
        #endif
    }
    func pickerController(didCancel pickerController: PhotoPickerController) {
        pickerController.dismiss(animated: true, completion: nil)
    }
    
    func pickerController(
        _ pickerController: PhotoPickerController,
        videoEditor editorViewController: EditorViewController,
        loadMusic
            completionHandler: @escaping ([VideoEditorMusicInfo]) -> Void
    ) -> Bool {
            completionHandler(Tools.musicInfos)
        return false
    }
}

@available(iOS 14.0, *)
extension PickerConfigurationViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(
        _ viewController: UIColorPickerViewController
    ) {
        config.setThemeColor(viewController.selectedColor)
    }
}

extension PickerConfigurationViewController {
    func presentThemeColor(_ indexPath: IndexPath) {
        if #available(iOS 14.0, *) {
            let vc = UIColorPickerViewController()
            vc.selectedColor = config.navigationTintColor ?? UIColor.systemBlue
            vc.delegate = self
            present(vc, animated: true, completion: nil)
        }
    }
    func presentColorConfig(_ indexPath: IndexPath) {
        let vc = PickerColorConfigurationViewController.init(config: config)
        vc.didDoneHandler = { [weak self] in
            self?.config = $0
        }
        present(UINavigationController.init(rootViewController: vc), animated: true, completion: nil)
    }
    func presentEditorConfig(_ indexPath: IndexPath) {
        let vc: EditorConfigurationViewController
        if #available(iOS 13.0, *) {
            vc = EditorConfigurationViewController.init(style: .insetGrouped)
        } else {
            vc = EditorConfigurationViewController.init(style: .grouped)
        }
        vc.config = config.editor
        vc.didDoneHandler = { [weak self] in
            self?.config.editor = $0
        }
        vc.showOpenEditorButton = false
        present(UINavigationController.init(rootViewController: vc), animated: true, completion: nil)
    }
    func presentStyleAction(_ indexPath: IndexPath) {
        if #available(iOS 13.0, *) {
            config.modalPresentationStyle = config.modalPresentationStyle == .fullScreen ? .automatic : .fullScreen
        }
        self.tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func isSplitAction(_ indexPath: IndexPath) {
        isSplitAction = !isSplitAction
        self.tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    func languageTypeAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "languageType", message: nil, preferredStyle: .alert)
        let titles = [
            "system",
            "simplifiedChinese",
            "traditionalChinese",
            "japanese",
            "korean",
            "english",
            "thai",
            "indonesia",
            "vietnamese",
            "russian",
            "german",
            "french",
            "Arabic",
            "Spanish",
            "Portuguese"
        ]
        for title in titles {
            alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                self.config.languageType = LanguageType.type(for: titles.firstIndex(of: action.title!)!)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func appearanceStyleAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "appearanceStyle", message: nil, preferredStyle: .alert)
        let titles = ["varied", "normal", "dark"]
        for title in titles {
            alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                self.config.appearanceStyle = AppearanceStyle.init(rawValue: titles.firstIndex(of: action.title!)!)!
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func shouldAutorotateAction(_ indexPath: IndexPath) {
        config.shouldAutorotate = !config.shouldAutorotate
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func selectOptionsAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "selectOptions", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: "photo", style: .default, handler: { [weak self](action) in
            guard let self = self else { return }
            self.config.selectOptions = .photo
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "gif+photo", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.gifPhoto]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "livePhoto+photo", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.livePhoto]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = .video
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "photo+video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.photo, .video]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "photo+gif+video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.gifPhoto, .video]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(
            UIAlertAction(title: "photo+livephoto+video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.livePhoto, .video]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(
            UIAlertAction(title: "photo+gif+livephoto+video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.gifPhoto, .livePhoto, .video]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        #if targetEnvironment(simulator)
        alert.addAction(
            UIAlertAction(title: "photo+gif+livephoto", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.photo, .gifPhoto, .livePhoto]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(
            UIAlertAction(title: "photo+gif+livephoto+video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.photo, .gifPhoto, .livePhoto, .video]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        #else
        alert.addAction(
            UIAlertAction(title: "photo+gif+livephoto+HDR", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.photo, .gifPhoto, .livePhoto, .HDRPhoto]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(
            UIAlertAction(title: "photo+gif+livephoto+HDR+video", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.config.selectOptions = [.photo, .gifPhoto, .livePhoto, .HDRPhoto, .video]
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        #endif
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func selectModeAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "selectMode", message: nil, preferredStyle: .alert)
        let titles = ["single", "multiple"]
        for title in titles {
            alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                self.config.selectMode = PickerSelectMode.init(rawValue: titles.firstIndex(of: action.title!)!)!
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    
    func allowSelectedTogetherAction(_ indexPath: IndexPath) {
        config.allowSelectedTogether = !config.allowSelectedTogether
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func allowLoadPhotoLibraryAction(_ indexPath: IndexPath) {
        config.allowLoadPhotoLibrary = !config.allowLoadPhotoLibrary
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func albumShowModeAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "albumShowMode", message: nil, preferredStyle: .alert)
        let titles = ["normal", "popup", "present"]
        for title in titles {
            alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let index = titles.firstIndex(of: action.title!)!
                if index == 0 {
                    self.config.albumShowMode = .normal
                }else if index == 1 {
                    self.config.albumShowMode = .popup
                }else {
                    if #available(iOS 13.0, *) {
                        self.config.albumShowMode = .present(.automatic)
                    } else {
                        self.config.albumShowMode = .present(.fullScreen)
                    }
                }
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func creationDateAction(_ indexPath: IndexPath) {
        config.creationDate = !config.creationDate
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func reverseOrderAction(_ indexPath: IndexPath) {
        config.photoList.sort = config.photoList.sort == .asc ? .desc : .asc
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func photoSelectionTapActionAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "photoSelectionTapAction", message: nil, preferredStyle: .alert)
        let titles = ["preview", "quickSelect", "openEditor"]
        for title in titles {
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let index = titles.firstIndex(of: action.title!)!
                self.config.photoSelectionTapAction = index == 0 ? .preview : index == 1 ? .quickSelect : .openEditor
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func videoSelectionTapActionAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "videoSelectionTapAction", message: nil, preferredStyle: .alert)
        let titles = ["preview", "quickSelect", "openEditor"]
        for title in titles {
            alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let index = titles.firstIndex(of: action.title!)!
                self.config.videoSelectionTapAction = index == 0 ? .preview : index == 1 ? .quickSelect : .openEditor
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func maximumSelectedPhotoCountAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "maximumSelectedPhotoCount", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.keyboardType = .numberPad
            textfield.text = String(self.config.maximumSelectedPhotoCount)
        }
        alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            let textFiled = alert.textFields?.first
            self.config.maximumSelectedPhotoCount = Int(textFiled?.text ?? "0") ?? 0
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func maximumSelectedVideoCountAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "maximumSelectedVideoCount", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.keyboardType = .numberPad
            textfield.text = String(self.config.maximumSelectedVideoCount)
        }
        alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            let textFiled = alert.textFields?.first
            self.config.maximumSelectedVideoCount = Int(textFiled?.text ?? "0") ?? 0
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func maximumSelectedCountAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "maximumSelectedCount", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.keyboardType = .numberPad
            textfield.text = String(self.config.maximumSelectedCount)
        }
        alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            let textFiled = alert.textFields?.first
            self.config.maximumSelectedCount = Int(textFiled?.text ?? "0") ?? 0
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func maximumSelectedVideoDurationAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "maximumSelectedVideoDuration", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.keyboardType = .numberPad
            textfield.text = String(self.config.maximumSelectedVideoDuration)
        }
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self]  (action) in
            guard let self = self else { return }
            let textFiled = alert.textFields?.first
            self.config.maximumSelectedVideoDuration = Int(textFiled?.text ?? "0") ?? 0
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func minimumSelectedVideoDurationAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "minimumSelectedVideoDuration", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.keyboardType = .numberPad
            textfield.text = String(self.config.minimumSelectedVideoDuration)
        }
        alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            let textFiled = alert.textFields?.first
            self.config.minimumSelectedVideoDuration = Int(textFiled?.text ?? "0") ?? 0
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func photoRowNumberAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "photoRowNumber", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.keyboardType = .numberPad
            textfield.text = String(self.config.photoList.rowNumber)
        }
        alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            let textFiled = alert.textFields?.first
            self.config.photoList.rowNumber = Int(textFiled?.text ?? "0") ?? 0
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }))
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func videoPlayTypeAction(_ indexPath: IndexPath) {
        let alert = UIAlertController.init(title: "videoPlayType", message: nil, preferredStyle: .alert)
        let titles = ["normal", "auto", "once"]
        for title in titles {
            alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let index = titles.firstIndex(of: action.title!)!
                self.config.previewView.videoPlayType = index == 0 ? .normal : index == 1 ? .auto : .once
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }))
        }
        alert.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        presendAlert(alert)
    }
    func addCameraAction(_ indexPath: IndexPath) {
        config.photoList.allowAddCamera = !config.photoList.allowAddCamera
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    func getRowContent(_ rowType: ConfigRowTypeRule) -> String {
        if let rowType = rowType as? ConfigRowType {
            switch rowType {
            case .languageType:
                return config.languageType.title
            case .appearanceStyle:
                return config.appearanceStyle.title
            case .shouldAutorotate:
                return config.shouldAutorotate ? "允许" : "不允许"
            case .selectOptions:
                return config.selectOptions.title
            case .selectMode:
                return config.selectMode.title
            case .allowSelectedTogether:
                return config.allowSelectedTogether ? "允许" : "不允许"
            case .allowLoadPhotoLibrary:
                return config.allowLoadPhotoLibrary ? "允许" : "不允许"
            case .albumShowMode:
                return config.albumShowMode.title
            case .creationDate:
                return config.creationDate ? "是" : "否"
            case .reverseOrder:
                return config.photoList.sort == .desc ? "是" : "否"
            case .photoSelectionTapAction:
                return config.photoSelectionTapAction.title
            case .videoSelectionTapAction:
                return config.videoSelectionTapAction.title
            case .maximumSelectedPhotoCount:
                return String(config.maximumSelectedPhotoCount)
            case .maximumSelectedVideoCount:
                return String(config.maximumSelectedVideoCount)
            case .maximumSelectedCount:
                return String(config.maximumSelectedCount)
            case .maximumSelectedVideoDuration:
                return String(config.maximumSelectedVideoDuration)
            case .minimumSelectedVideoDuration:
                return String(config.minimumSelectedVideoDuration)
            case .photoRowNumber:
                return String(config.photoList.rowNumber)
            case .videoPlayType:
                return config.previewView.videoPlayType.title
            case .addCamera:
                return config.photoList.allowAddCamera ? "true" : "false"
            }
        }
        if let type = rowType as? ViewControllerOptionsRowType {
            switch type {
            case .presentStyle:
                return config.modalPresentationStyle == .fullScreen ? "true" : "false"
            case .isSplit:
                return isSplitAction ? "true" : "false"
            }
        }
        return ""
    }
}
extension PickerConfigurationViewController {
    
    enum ConfigSection: Int, CaseIterable {
        case viewContollerOptions
        case pickerOptions
        case editorOptions
        case colorOptions
        
        var title: String {
            switch self {
            case .viewContollerOptions:
                return "ViewContollerOptions"
            case .pickerOptions:
                return "PickerOptions"
            case .colorOptions:
                return "ColorOptions"
            case .editorOptions:
                return "EditorOptions"
            }
        }
        
        var allRowCase: [ConfigRowTypeRule] {
            switch self {
            case .viewContollerOptions:
                return ViewControllerOptionsRowType.allCases
            case .pickerOptions:
                return ConfigRowType.allCases
            case .colorOptions:
                return ColorRowType.allCases
            case .editorOptions:
                return EditorRowType.allCases
            }
        }
    }
    enum ViewControllerOptionsRowType: String, CaseIterable, ConfigRowTypeRule {
        case presentStyle
        case isSplit
        
        var title: String {
            switch self {
            case .presentStyle:
                return "是否全屏"
            case .isSplit:
                return "Use UISplitViewController"
            }
        }
        
        var detailTitle: String {
            switch self {
            case .presentStyle:
                return "modalPresentationStyle"
            case .isSplit:
                return "PhotoSplitViewController"
            }
        }
        
        func getFunction<T>(
            _ controller: T
        ) -> ((IndexPath) -> Void) where T: UIViewController {
            guard let controller = controller as? PickerConfigurationViewController else { return { _ in } }
            switch self {
            case .presentStyle:
                return controller.presentStyleAction(_:)
            case .isSplit:
                return controller.isSplitAction(_:)
            }
        }
    }
    enum ColorRowType: String, CaseIterable, ConfigRowTypeRule {
        case theme
        case color
        
        var title: String {
            switch self {
            case .theme:
                "设置主题色"
            case .color:
                "设置颜色"
            }
        }
        
        var detailTitle: String {
            switch self {
            case .theme:
                "setThemeColor()"
            case .color:
                ".color"
            }
        }
        
        func getFunction<T>(
            _ controller: T) -> (
                (IndexPath) -> Void
            ) where T: UIViewController {
            guard let controller = controller as? PickerConfigurationViewController else { return { _ in } }
            switch self {
            case .theme:
                return controller.presentThemeColor(_:)
            case .color:
                return controller.presentColorConfig(_:)
            }
        }
    }
    enum EditorRowType: String, CaseIterable, ConfigRowTypeRule {
        case color
        
        var title: String {
            "编辑配置"
        }
        
        var detailTitle: String {
            ".editor"
        }
        
        func getFunction<T>(
            _ controller: T) -> (
                (IndexPath) -> Void
            ) where T: UIViewController {
            guard let controller = controller as? PickerConfigurationViewController else { return { _ in } }
            return controller.presentEditorConfig(_:)
        }
    }
    
    enum ConfigRowType: String, CaseIterable, ConfigRowTypeRule {
        case languageType
        case appearanceStyle
        case shouldAutorotate
        case selectOptions
        case selectMode
        case maximumSelectedPhotoCount
        case maximumSelectedVideoCount
        case maximumSelectedCount
        case photoRowNumber
        case allowSelectedTogether
        case allowLoadPhotoLibrary
        case albumShowMode
        case creationDate
        case reverseOrder
        case photoSelectionTapAction
        case videoSelectionTapAction
        case maximumSelectedVideoDuration
        case minimumSelectedVideoDuration
        case videoPlayType
        case addCamera
        
        var title: String {
            switch self {
            case .languageType:
                return "语言类型"
            case .appearanceStyle:
                return "外观风格"
            case .shouldAutorotate:
                return "允许旋转(全屏情况下有效)"
            case .selectOptions:
                return "资源类型"
            case .selectMode:
                return "选择模式"
            case .allowSelectedTogether:
                return "照片和视频可以同时选择"
            case .allowLoadPhotoLibrary:
                return "允许加载系统照片库"
            case .albumShowMode:
                return "相册展示模式"
            case .creationDate:
                return "按创建时间排序"
            case .reverseOrder:
                return "按倒序展示"
            case .photoSelectionTapAction:
                return "列表照片Cell点击动作"
            case .videoSelectionTapAction:
                return "列表视频Cell点击动作"
            case .maximumSelectedPhotoCount:
                return "最多可以选择的照片数"
            case .maximumSelectedVideoCount:
                return "最多可以选择的视频数"
            case .maximumSelectedCount:
                return "最多可以选择的总数"
            case .maximumSelectedVideoDuration:
                return "视频最大选择时长"
            case .minimumSelectedVideoDuration:
                return "视频最小选择时长"
            case .photoRowNumber:
                return "每行显示数量"
            case .videoPlayType:
                return "视频播放类型"
            case .addCamera:
                return "列表添加相机"
            }
        }
        var detailTitle: String {
            if self == .photoRowNumber {
                return ".photoList.rowNumber"
            }
            if self == .videoPlayType {
                return ".previewView.videoPlayType"
            }
            if self == .addCamera {
                return ".PhotoList.allowAddCamera"
            }
            return "." + self.rawValue
        }
        
        func getFunction<T>(
            _ controller: T) -> (
                (IndexPath) -> Void
            ) where T: UIViewController {
            guard let controller = controller as? PickerConfigurationViewController else { return { _ in } }
            switch self {
            case .languageType:
                return controller.languageTypeAction(_:)
            case .appearanceStyle:
                return controller.appearanceStyleAction(_:)
            case .shouldAutorotate:
                return controller.shouldAutorotateAction(_:)
            case .selectOptions:
                return controller.selectOptionsAction(_:)
            case .selectMode:
                return controller.selectModeAction(_:)
            case .allowSelectedTogether:
                return controller.allowSelectedTogetherAction(_:)
            case .allowLoadPhotoLibrary:
                return controller.allowLoadPhotoLibraryAction(_:)
            case .albumShowMode:
                return controller.albumShowModeAction(_:)
            case .creationDate:
                return controller.creationDateAction(_:)
            case .reverseOrder:
                return controller.reverseOrderAction(_:)
            case .photoSelectionTapAction:
                return controller.photoSelectionTapActionAction(_:)
            case .videoSelectionTapAction:
                return controller.videoSelectionTapActionAction(_:)
            case .maximumSelectedPhotoCount:
                return controller.maximumSelectedPhotoCountAction(_:)
            case .maximumSelectedVideoCount:
                return controller.maximumSelectedVideoCountAction(_:)
            case .maximumSelectedCount:
                return controller.maximumSelectedCountAction(_:)
            case .maximumSelectedVideoDuration:
                return controller.maximumSelectedVideoDurationAction(_:)
            case .minimumSelectedVideoDuration:
                return controller.minimumSelectedVideoDurationAction(_:)
            case .photoRowNumber:
                return controller.photoRowNumberAction(_:)
            case .videoPlayType:
                return controller.videoPlayTypeAction(_:)
            case .addCamera:
                return controller.addCameraAction(_:)
            }
        }
    }
}

extension LanguageType {
    var title: String {
        switch self {
        case .system:
            return "系统语言"
        case .simplifiedChinese:
            return "中文简体"
        case .traditionalChinese:
            return "中文繁体"
        case .japanese:
            return "日文"
        case .korean:
            return "韩文"
        case .english:
            return "英文"
        case .thai:
            return "泰语"
        case .indonesia:
            return "印尼语"
        case .vietnamese:
            return "越南语"
        case .russian:
            return "俄语"
        case .german:
            return "德语"
        case .french:
            return "法语"
        case .arabic:
            return "阿拉伯"
        case .spanish:
            return "西班牙"
        case .portuguese:
            return "葡萄牙"
        case .custom:
            return "自定义"
        }
    }
}

extension AppearanceStyle {
    var title: String {
        switch self {
        case .varied:
            return "跟随系统变化"
        case .normal:
            return "正常风格"
        case .dark:
            return "暗黑风格"
        }
    }
}

extension PickerAssetOptions {
    var title: String {
        if self == [
            .photo,
            .gifPhoto,
            .livePhoto,
            .video] ||
            self == [
            .gifPhoto,
            .livePhoto,
            .video] {
            return "photo+gif+livePhoto+video"
        }
        if self == [.photo, .gifPhoto, .video] || self == [.gifPhoto, .video] {
            return "photo+gif+video"
        }
        if self == [.photo, .livePhoto, .video] || self == [.livePhoto, .video] {
            return "photo+livePhoto+video"
        }
        if self == [.photo, .gifPhoto, .livePhoto] {
            return "photo+gif+livePhoto"
        }
        if self == [.photo, .gifPhoto, .livePhoto, .HDRPhoto] {
            return "photo+gif+livePhoto+HDRPhoto"
        }
        if self == [.photo, .gifPhoto] {
            return "photo+gif"
        }
        if self == [.photo, .livePhoto] {
            return "photo+livePhoto"
        }
        if self == [.photo, .video] {
            return "photo+video"
        }
        if self == [.photo, .gifPhoto, .livePhoto, .HDRPhoto] {
            return "photo+gifPhoto+livePhoto+HDRPhoto"
        }
        if self == [.photo, .gifPhoto, .livePhoto, .HDRPhoto, .video] {
            return "photo+gifPhoto+livePhoto+HDRPhoto+video"
        }
        switch self {
        case .photo:
            return "photo"
        case .gifPhoto:
            return "photo+gifPhoto"
        case .livePhoto:
            return "photo+livePhoto"
        case .video:
            return "video"
        default:
            return "photo+video"
        }
    }
}
extension PickerSelectMode {
    var title: String {
        switch self {
        case .single:
            return "单选"
        case .multiple:
            return "多选"
        }
    }
}
extension AlbumShowMode {
    var title: String {
        switch self {
        case .normal:
            return "单独控制器"
        case .popup:
            return "弹窗"
        case .present:
            return "弹窗控制器"
        }
    }
}
extension SelectionTapAction {
    var title: String {
        switch self {
        case .preview:
            return "预览"
        case .quickSelect:
            return "快速选择"
        case .openEditor:
            return "打开编辑器"
        }
    }
}
extension PhotoPreviewViewController.PlayType {
    var title: String {
        switch self {
        case .normal:
            return "不自动播放"
        case .auto:
            return "自动播放"
        case .once:
            return "自动播放一次"
        }
    }
}

extension LanguageType {
    
    static func type(for value: Int) -> LanguageType {
        switch value {
        case 1:
            return .simplifiedChinese
        case 2:
            return .traditionalChinese
        case 3:
            return .japanese
        case 4:
            return .korean
        case 5:
            return .english
        case 6:
            return .thai
        case 7:
            return .indonesia
        case 8:
            return .vietnamese
        case 9:
            return .russian
        case 10:
            return .german
        case 11:
            return .french
        case 12:
            return .arabic
        case 13:
            return .spanish
        case 14:
            return .portuguese
        default:
            return .system
        }
    }
}
