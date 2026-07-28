// SCNavigationView.swift
import UIKit
import SnapKit

class MINavigationView: UIView {
    
    var style: MINavigationStyleConfiguration
    let contentView = UIView()
    var backButton: UIButton?
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    var leftButtonView: MINavigationButtonView?
    var rightButtonView: MINavigationButtonView?
    
    var lineView: UIView = UIView()
    
    var backButtonHidden: Bool = false {
        didSet {
            backButton?.isHidden = backButtonHidden
        }
    }
    
    var backButtonClickBlock: (() -> Void)?
    
    var title: String? {
        get {
            return titleLabel.attributedText?.string
        }
        set {
            if let newValue = newValue {
                attributedTitle = NSAttributedString(
                    string: newValue,
                    attributes: style.titleTextAttributes
                )
            } else {
                attributedTitle = nil
            }
        }
    }
    
    var attributedTitle: NSAttributedString? {
        get {
            return titleLabel.attributedText
        }
        set {
            titleLabel.attributedText = newValue
        }
    }
    
    var subtitle: String? {
        get {
            return subtitleLabel.text
        }
        set {
            subtitleLabel.text = newValue
            subtitleLabel.isHidden = newValue == nil || newValue?.isEmpty == true
        }
    }
    
    static func contentHeight() -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 80
        }
        else{
            return 70
        }
    }
    
    static func getNavigaionViewHeight() -> CGFloat {
        let statusBarHeight: CGFloat
        
        if #available(iOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return 0
            }
            
            if #available(iOS 15.0, *) {
                statusBarHeight = windowScene.keyWindow?.safeAreaInsets.top ?? 0
            } else {
                statusBarHeight = windowScene.windows.first?.safeAreaInsets.top ?? 0
            }
        } else {
            statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        }
        
        return statusBarHeight + MINavigationView.contentHeight()
    }
    
    static func navigationViewForViewController(_ viewController: UIViewController) -> MINavigationView {
        return navigationViewForViewController(viewController, styleConfiguration: nil)
    }
    
    static func navigationViewForViewController(_ viewController: UIViewController, styleConfiguration: MINavigationStyleConfiguration?) -> MINavigationView {
        let style = styleConfiguration ?? MINavigationStyleConfiguration.default.copy() as! MINavigationStyleConfiguration
        let frame = CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: getNavigaionViewHeight()
        )
        
        let navigationView = MINavigationView(frame: frame, navigationStyle: style)
        navigationView.title = viewController.title
        return navigationView
    }
    
    init(frame: CGRect, navigationStyle: MINavigationStyleConfiguration) {
        self.style = navigationStyle
        super.init(frame: frame)
        initNavigationSubviews()
        updateStyleConfigurations()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupButtonEventsOnViewWillAppearForViewContoller(_ viewController: UIViewController) {
        guard backButtonClickBlock == nil else { return }
        
        let isPresent = viewController.presentingViewController != nil || viewController.navigationController?.presentingViewController != nil
        
        if let navigationController = viewController.navigationController, navigationController.viewControllers.count > 1 {
            backButtonHidden = false
            backButtonClickBlock = { [weak viewController] in
                viewController?.navigationController?.popViewController(animated: true)
            }
        } else if isPresent {
            backButton?.setBackgroundImage(MINavigationStyleConfiguration.defaultCloseButtonImage(), for: .normal)
            backButtonHidden = false
            backButtonClickBlock = { [weak viewController] in
                viewController?.dismiss(animated: true, completion: nil)
            }
        } else {
            backButtonHidden = true
        }
    }
    
    private func initNavigationSubviews() {
        addSubview(contentView)
        
        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(MINavigationView.contentHeight())
        }
        
        lineView.backgroundColor = "#000000".color.withAlpha(0.05)
        addSubview(lineView)
        lineView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(0.5)
            make.bottom.equalToSuperview()
        }
        
        // 设置标题标签
        subtitleLabel.numberOfLines = 1
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.font = SFCompact(size: 17)
        subtitleLabel.textColor = "#333333".color
        
        // 设置二级标题标签
        subtitleLabel.numberOfLines = 1
        subtitleLabel.textAlignment = .center
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.font = SFCompact(weight: .regular, size: 12)
        subtitleLabel.textColor = "#000000".color.withAlphaComponent(0.38)
        subtitleLabel.isHidden = true
        
        addSubview(subtitleLabel)
        addSubview(titleLabel)
        
        if UIDevice.isPhone {
            subtitleLabel.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-8)
            }
            titleLabel.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalTo(subtitleLabel.snp.top).offset(-10)
            }
        }
        
        if UIDevice.isPad {
            subtitleLabel.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.height.equalTo(15)
                $0.bottom.equalToSuperview().offset(-8)
            }
            titleLabel.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalTo(subtitleLabel.snp.top).offset(-10)
            }
        }
        
        
        backButton = addLeftBarButtonItemWithImage(style.backButtonImage, target: self, action: #selector(backButtonAction))
        
        layer.shadowOpacity = 1.0
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }
    
    func navigationTitleLabel() -> UILabel {
        return titleLabel
    }
    
    func navigationSubtitleLabel() -> UILabel {
        return subtitleLabel
    }
    
    func configNavigationStyle(_ block: @escaping (MINavigationStyleConfiguration) -> Void) {
        block(style)
        updateStyleConfigurations()
    }
    
    private func updateStyleConfigurations() {
        backgroundColor = style.barTintColor
        titleLabel.numberOfLines = style.numberOfLinesForTitle == 2 ? 2 : 1
        
        if let currentTitle = title {
            self.title = currentTitle
        }
        
        // 更新二级标题样式
        if let currentSubtitle = subtitle {
            self.subtitle = currentSubtitle
        }
        
        backButton?.setImage(style.backButtonImage, for: .normal)
        
        if let rightButtons = rightBarButtons(), !rightButtons.isEmpty {
            rightButtonView?.setButtonTitleAttributes(style.barButtonTitleAttributes, preferredButtonSize: style.imageButtonSize)
        }
        
        layer.shadowColor = style.sepratorLineColor.cgColor
    }
    
    @objc private func backButtonAction() {
        backButtonClickBlock?()
    }
    
    // MARK: - Left Button Methods
    
    func leftBarButtons() -> [UIButton]? {
        return leftButtonView?.buttonArray
    }
    
    private func ensureLeftButtonView() -> MINavigationButtonView {
        if leftButtonView == nil {
            leftButtonView = MINavigationButtonView()
            // layoutDirection removed
            contentView.addSubview(leftButtonView!)
            
            leftButtonView?.setButtonTitleAttributes(style.barButtonTitleAttributes, preferredButtonSize: style.imageButtonSize)
            
            leftButtonView?.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(style.horizontalContentInset.leading)
                make.top.bottom.equalToSuperview()
            }
        }
        return leftButtonView!
    }
    
    @discardableResult
    func addLeftBarButtonItemWithTitle(_ title: String, target: Any?, action: Selector) -> UIButton? {
        let buttonView = ensureLeftButtonView()
        guard let button = buttonView.addButtonWithTitle(title) else { return nil }
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    func addLeftBarButtonItemWithTitle(_ title: String, _ callBack: @escaping UIButtonClickClosure) -> UIButton? {
        let buttonView = ensureLeftButtonView()
        guard let button = buttonView.addButtonWithTitle(title) else { return nil }
        button.addClickClosure(callBack)
        return button
    }
    
    @discardableResult
    func addLeftBarButtonItemWithImage(_ image: UIImage?, target: Any?, action: Selector) -> UIButton? {
        let buttonView = ensureLeftButtonView()
        guard let image = image, let button = buttonView.addButtonItemWithImage(image) else { return nil }
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    @discardableResult
    func addLeftBarButtonItemWithImage(_ image: UIImage?, _ callBack: @escaping UIButtonClickClosure) -> UIButton? {
        let buttonView = ensureLeftButtonView()
        guard let image = image, let button = buttonView.addButtonItemWithImage(image) else { return nil }
        button.addClickClosure(callBack)
        return button
    }
    
    func removeAllLeftButtons() {
        leftButtonView?.removeFromSuperview()
        leftButtonView = nil
    }
    
    // MARK: - Right Button Methods
    
    func rightBarButtons() -> [UIButton]? {
        return rightButtonView?.buttonArray
    }
    
    private func ensureRightButtonView() -> MINavigationButtonView {
        if rightButtonView == nil {
            rightButtonView = MINavigationButtonView()
            // layoutDirection removed
            contentView.addSubview(rightButtonView!)
            
            rightButtonView?.setButtonTitleAttributes(style.barButtonTitleAttributes, preferredButtonSize: style.imageButtonSize)
            
            rightButtonView?.snp.makeConstraints { make in
                if UIDevice.current.userInterfaceIdiom == .pad {
                    make.trailing.equalToSuperview().offset(-style.horizontalContentInset.right*2)
                }else{
                    make.trailing.equalToSuperview().offset(-style.horizontalContentInset.trailing)
                }
                make.top.bottom.equalToSuperview()
            }
        }
        return rightButtonView!
    }
    
    @discardableResult
    func addRightBarButtonItemWithImage(_ image: UIImage?,_ selectImg:UIImage = UIImage(), target: Any?, action: Selector) -> UIButton? {
        let buttonView = ensureRightButtonView()
        guard let image = image, let button = buttonView.addButtonItemWithImage(image,selectImg) else { return nil }
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    @discardableResult
    func addRightBarButtonItemWithImage(_ image: UIImage?,_ selectImg:UIImage = UIImage(), _ callBack: @escaping UIButtonClickClosure) -> UIButton? {
        let buttonView = ensureRightButtonView()
        guard let image = image, let button = buttonView.addButtonItemWithImage(image,selectImg) else { return nil }
        button.addClickClosure(callBack)
        return button
    }
    
    @discardableResult
    func addRightBarButtonItemWithTitle(_ title: String, target: Any?, action: Selector) -> UIButton? {
        let buttonView = ensureRightButtonView()
        guard let button = buttonView.addButtonWithTitle(title) else { return nil }
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    @discardableResult
    func addRightBarButtonItemWithTitle(_ title: String, _ callBack: @escaping UIButtonClickClosure) -> UIButton? {
        let buttonView = ensureRightButtonView()
        guard let button = buttonView.addButtonWithTitle(title) else { return nil }
        button.addClickClosure(callBack)
        return button
    }
    
    func removeAllRightButtons() {
        rightButtonView?.removeFromSuperview()
        rightButtonView = nil
    }
    
    func removeNavigationBarButton(_ button: UIButton) {
        if leftButtonView?.buttonArray.contains(button) == true {
            leftButtonView?.removeButton(button)
        } else if rightButtonView?.buttonArray.contains(button) == true {
            rightButtonView?.removeButton(button)
        }
    }
}
