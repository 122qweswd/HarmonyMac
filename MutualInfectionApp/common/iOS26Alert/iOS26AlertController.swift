//
//  iOS26AlertController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/28.
//

import UIKit
import SnapKit

// MARK: - Action style & model

/// 弹窗按钮样式枚举
public enum iOS26AlertActionStyle {
    case `default`
    case cancel
    case destructive
    case custom(background: UIColor, text: UIColor)
}

/// 弹窗按钮模型
public struct iOS26AlertAction {
    public let title: String
    public let style: iOS26AlertActionStyle
    public let handler: (() -> Void)?
    
    public init(title: String, style: iOS26AlertActionStyle = .default, handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

// MARK: - Blur Style

/// 毛玻璃样式配置
public enum iOS26AlertBlurStyle {
    case light
    case extraLight
    case dark
    case regular
    case prominent
    case systemUltraThinMaterial
    case systemThinMaterial
    case systemMaterial
    case systemThickMaterial
    case systemChromeMaterial
    /**
     // 1. 弹窗和浮层 - 最常用
     .systemThinMaterial      // 适中的透明度，适合弹窗背景
     .systemMaterial          // 稍微更实，适合重要弹窗

     // 2. 工具栏和导航栏
     .systemChromeMaterial    // 专门为工具栏设计
     .systemThickMaterial     // 底部工具栏

     // 3. 卡片和内容区域
     .systemUltraThinMaterial // 非常轻量，适合内容卡片
     .systemThinMaterial      // 中等透明度，通用性强

     // 4. 传统样式（特定需求）
     .light                   // 需要固定浅色背景时
     .dark                    // 需要固定深色背景时

     */
    /// 转换为 UIBlurEffect.Style
    var uiBlurEffect: UIBlurEffect {
        switch self {
        case .light:
            return UIBlurEffect(style: .light)
        case .extraLight:
            return UIBlurEffect(style: .extraLight)
        case .dark:
            return UIBlurEffect(style: .dark)
        case .regular:
            return UIBlurEffect(style: .regular)
        case .prominent:
            return UIBlurEffect(style: .prominent)
        case .systemUltraThinMaterial:
            return UIBlurEffect(style: .systemUltraThinMaterial)
        case .systemThinMaterial:
            return UIBlurEffect(style: .systemThinMaterial)
        case .systemMaterial:
            return UIBlurEffect(style: .systemMaterial)
        case .systemThickMaterial:
            return UIBlurEffect(style: .systemThickMaterial)
        case .systemChromeMaterial:
            return UIBlurEffect(style: .systemChromeMaterial)
        }
    }
}

// MARK: - iOS26AlertView (UI & interaction; used as controller's root view)

final class iOS26AlertView: UIView {
    
    // MARK: - 配置属性
    
    /// 是否自动关闭弹窗
    var autoDismiss: Bool = false
    
    /// 是否允许点击背景关闭
    var dismissOnBackgroundTap: Bool = true
    
    // MARK: - 回调
    
    /// 按钮点击回调
    var onActionTapped: ((iOS26AlertAction, Bool) -> Void)?
    
    /// 毛玻璃样式变化回调
    var onBlurStyleChanged: ((iOS26AlertBlurStyle) -> Void)?
    
    // MARK: - UI 组件
    
    /// 背景遮罩视图
    private let dimmingView = UIView()
    
    /// 内容容器视图
    private let containerView = UIView()
    
    /// 毛玻璃效果视图
    private let blurEffectView = UIVisualEffectView()
    
    /// 文本容器视图
    private let textContainer = UIView()
    
    /// 按钮堆栈视图
    private let buttonStack = UIStackView()
    
    /// 标题标签
    private let titleLabel = UILabel()
    
    /// 消息标签
    private let messageLabel = UILabel()
    
    // MARK: - 数据
    
    /// 按钮数组
    private var actions: [iOS26AlertAction] = []
    
    /// 标题文本
    private var titleText: String?
    
    /// 消息文本
    private var messageText: String?
    
    /// 当前毛玻璃样式
    private var currentBlurStyle: iOS26AlertBlurStyle
    
    // MARK: - 初始化
    
    /// 初始化弹窗视图
    init(title: String? = nil,
         message: String? = nil,
         actions: [iOS26AlertAction],
         autoDismiss: Bool = false,
         blurStyle: iOS26AlertBlurStyle) {
        self.titleText = title
        self.messageText = message
        self.actions = actions
        self.autoDismiss = autoDismiss
        self.currentBlurStyle = blurStyle
        
        super.init(frame: .zero)
        
        setupUI()
        setupLayout()
        setupButtons()
        
        // 设置初始动画状态
        containerView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        containerView.alpha = 0
        dimmingView.alpha = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI 设置
    
    /// 设置用户界面
    private func setupUI() {
        backgroundColor = .clear
        isOpaque = false
        
        // 设置背景遮罩
        setupDimmingView()
        
        // 设置内容容器
        setupContainerView()
        
        // 设置毛玻璃效果
        setupBlurEffect()
        
        // 设置文本容器
        setupTextContainer()
        
        // 设置按钮堆栈
        setupButtonStack()
    }
    
    /// 设置背景遮罩视图
    private func setupDimmingView() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        addSubview(dimmingView)
        
        // 添加点击手势
        if dismissOnBackgroundTap {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dimmingTapped))
            dimmingView.addGestureRecognizer(tap)
        }
    }
    
    /// 设置内容容器视图
    private func setupContainerView() {
        addSubview(containerView)
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 34
        containerView.clipsToBounds = true
    }
    
    /// 设置毛玻璃效果
    private func setupBlurEffect() {
        // 创建毛玻璃效果
        let blurEffect = currentBlurStyle.uiBlurEffect
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 34
        blurEffectView.clipsToBounds = true
        containerView.addSubview(blurEffectView)
        
        // 添加轻微遮罩层增强可读性
        let vibrancyView = UIView()
        vibrancyView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        vibrancyView.layer.cornerRadius = 34
        vibrancyView.clipsToBounds = true
        containerView.addSubview(vibrancyView)
    }
    
    /// 设置文本容器
    private func setupTextContainer() {
        containerView.addSubview(textContainer)
        
        // 设置标题标签（如果有标题）
        if let title = titleText {
            setupTitleLabel(title)
        }
        
        // 设置消息标签
        setupMessageLabel()
    }
    
    /// 设置标题标签
    private func setupTitleLabel(_ title: String) {
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        textContainer.addSubview(titleLabel)
    }
    
    /// 设置消息标签
    private func setupMessageLabel() {
        messageLabel.text = messageText
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.textAlignment = .center
        messageLabel.textColor = UIColor(hex: "#3c3c4399")
        messageLabel.numberOfLines = 0
        textContainer.addSubview(messageLabel)
    }
    
    /// 设置按钮堆栈
    private func setupButtonStack() {
        buttonStack.axis = actions.count > 1 ? .horizontal : .vertical
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = actions.count > 1 ? 8 : 0
        containerView.addSubview(buttonStack)
    }
    
    // MARK: - 布局设置
    
    /// 设置布局约束
    private func setupLayout() {
        setupDimmingViewLayout()
        setupContainerViewLayout()
        setupBlurEffectLayout()
        setupTextContainerLayout()
        setupButtonStackLayout()
    }
    
    /// 设置背景遮罩布局
    private func setupDimmingViewLayout() {
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    /// 设置内容容器布局
    private func setupContainerViewLayout() {
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(320)
        }
    }
    
    /// 设置毛玻璃效果布局
    private func setupBlurEffectLayout() {
        // 毛玻璃视图填满整个容器
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 振动效果视图也填满整个容器
        if let vibrancyView = containerView.subviews.first(where: {
            $0 != blurEffectView && $0 != textContainer && $0 != buttonStack
        }) {
            vibrancyView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    /// 设置文本容器布局
    private func setupTextContainerLayout() {
        textContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(containerView)
        }
        
        if titleLabel.superview != nil {
            // 有标题的情况
            titleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(22)
                make.leading.equalToSuperview().offset(30)
                make.trailing.equalToSuperview().inset(30)
            }
            
            messageLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(7)
                make.leading.trailing.equalTo(titleLabel)
                make.bottom.equalToSuperview().inset(4)
            }
        } else {
            // 无标题的情况
            messageLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(22)
                make.leading.equalToSuperview().offset(30)
                make.trailing.equalToSuperview().inset(30)
                make.bottom.equalToSuperview().inset(4)
            }
        }
    }
    
    /// 设置按钮堆栈布局
    private func setupButtonStackLayout() {
        buttonStack.snp.makeConstraints { make in
            make.top.equalTo(textContainer.snp.bottom)
            make.leading.equalTo(containerView).offset(16)
            make.trailing.equalTo(containerView).inset(16)
            make.bottom.equalTo(containerView).inset(16)
            make.height.equalTo(48)
        }
    }
    
    // MARK: - 按钮设置
    
    /// 设置按钮
    private func setupButtons() {
        // 移除现有按钮
        buttonStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 添加新按钮
        for (index, action) in actions.enumerated() {
            let button = createButton(for: action, at: index)
            buttonStack.addArrangedSubview(button)
        }
    }
    
    /// 创建单个按钮
    private func createButton(for action: iOS26AlertAction, at index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.setTitle(action.title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(titleColor(for: action), for: .normal)
        button.backgroundColor = buttonBackgroundColor(for: action)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        // 设置按钮高度
        button.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        
        return button
    }
    
    /// 获取按钮背景颜色
    private func buttonBackgroundColor(for action: iOS26AlertAction) -> UIColor {
        switch action.style {
        case .default:
            return .systemBlue
        case .cancel:
            return .secondarySystemFill
        case .destructive:
            return .systemRed
        case .custom(let bg, _):
            return bg
        }
    }
    
    /// 获取按钮标题颜色
    private func titleColor(for action: iOS26AlertAction) -> UIColor {
        switch action.style {
        case .default:
            return .white
        case .cancel:
            return .label
        case .destructive:
            return .white
        case .custom(_, let txt):
            return txt
        }
    }
    
    // MARK: - 交互处理
    
    /// 背景点击处理
    @objc private func dimmingTapped() {
        if dismissOnBackgroundTap {
            onActionTapped?(iOS26AlertAction(title: "", style: .cancel, handler: nil), true)
        }
    }
    
    /// 按钮点击处理
    @objc private func buttonTapped(_ sender: UIButton) {
        guard sender.tag < actions.count else { return }
        let action = actions[sender.tag]
        
        // 按钮点击动画
        animateButtonTap(sender)
        
        // 判断是否需要关闭弹窗
        let shouldDismiss = shouldDismissForAction(action)
        
        // 触发回调
        onActionTapped?(action, shouldDismiss)
    }
    
    /// 按钮点击动画
    private func animateButtonTap(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
    }
    
    /// 判断操作是否需要关闭弹窗
    private func shouldDismissForAction(_ action: iOS26AlertAction) -> Bool {
        switch action.style {
        case .cancel:
            return true
        default:
            return autoDismiss
        }
    }
    
    // MARK: - 动画效果
    
    /// 进入动画
    func animateIn() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
            self.dimmingView.alpha = 1
        }, completion: nil)
    }
    
    /// 退出动画
    func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
            self.dimmingView.alpha = 0
        }, completion: { _ in
            completion()
        })
    }
    
    // MARK: - 公共方法
    
    /// 更新毛玻璃样式
    func updateBlurStyle(_ style: iOS26AlertBlurStyle) {
        currentBlurStyle = style
        let blurEffect = style.uiBlurEffect
        
        UIView.animate(withDuration: 0.3) {
            self.blurEffectView.effect = blurEffect
        }
        
        onBlurStyleChanged?(style)
    }
    
    /// 获取当前毛玻璃样式
    func getCurrentBlurStyle() -> iOS26AlertBlurStyle {
        return currentBlurStyle
    }
}

// MARK: - iOS26AlertController

public final class iOS26AlertController: UIViewController {
    
    // MARK: - 属性
    
    /// 弹窗视图
    private let alertView: iOS26AlertView
    
    /// 当前毛玻璃样式
    public var blurStyle: iOS26AlertBlurStyle {
        get {
            return alertView.getCurrentBlurStyle()
        }
        set {
            alertView.updateBlurStyle(newValue)
        }
    }
    
    // MARK: - 初始化
    
    /// 初始化弹窗控制器
    public init(title: String? = nil,
                message: String? = nil,
                actions: [iOS26AlertAction],
                autoDismiss: Bool = false,
                blurStyle: iOS26AlertBlurStyle = .systemThinMaterial) {
        self.alertView = iOS26AlertView(
            title: title,
            message: message,
            actions: actions,
            autoDismiss: autoDismiss,
            blurStyle: blurStyle
        )
        
        super.init(nibName: nil, bundle: nil)
        
        // 设置模态展示样式
        setupModalPresentation()
        
        // 绑定回调
        bindCallbacks()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    
    public override func loadView() {
        self.view = alertView
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 开始进入动画
        alertView.animateIn()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    // MARK: - 设置
    
    /// 设置模态展示样式
    private func setupModalPresentation() {
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        modalPresentationCapturesStatusBarAppearance = true
    }
    
    /// 绑定回调
    private func bindCallbacks() {
        alertView.onActionTapped = { [weak self] action, shouldDismiss in
            guard let self = self else { return }
            
            // 获取按钮处理器
            let handler = action.handler
            
            if shouldDismiss {
                // 需要关闭弹窗
                self.dismissAlert(animated: true) {
                    handler?()
                }
            } else {
                // 不需要关闭弹窗，直接执行处理器
                handler?()
            }
        }
        
        // 毛玻璃样式变化回调
        alertView.onBlurStyleChanged = { [weak self] style in
            // 可以在这里处理样式变化，例如更新状态栏样式等
            self?.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    // MARK: - 公共方法
    
    /// 关闭弹窗
    public func dismissAlert(animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated {
            alertView.animateOut {
                self.dismiss(animated: false, completion: completion)
            }
        } else {
            self.dismiss(animated: false, completion: completion)
        }
    }
    
    /// 从指定视图控制器展示弹窗
    public func present(from vc: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        vc.present(self, animated: animated, completion: completion)
    }
    
    // MARK: - 状态栏样式
    
    /// 状态栏样式
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        switch blurStyle {
        case .dark, .systemMaterial, .systemThickMaterial, .systemChromeMaterial:
            return .lightContent
        default:
            return .default
        }
    }
}

// MARK: - UIColor hex helper

extension UIColor {
    /// 通过十六进制字符串创建颜色
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r, g, b, a: UInt64
        switch hexSanitized.count {
        case 8: // RRGGBBAA
            r = (rgb & 0xff000000) >> 24
            g = (rgb & 0x00ff0000) >> 16
            b = (rgb & 0x0000ff00) >> 8
            a = rgb & 0x000000ff
        case 6: // RRGGBB
            r = (rgb & 0xff0000) >> 16
            g = (rgb & 0x00ff00) >> 8
            b = rgb & 0x0000ff
            a = 255
        default:
            r = 0; g = 0; b = 0; a = 255
        }
        
        self.init(red: CGFloat(r) / 255.0,
                  green: CGFloat(g) / 255.0,
                  blue: CGFloat(b) / 255.0,
                  alpha: CGFloat(a) / 255.0)
    }
}

// MARK: - 便捷扩展方法

public extension iOS26AlertController {
    
    static func showConfirmation(
        title: String? = nil,
        message: String? = nil,
        confirmTitle: String = "确认",
        cancelTitle: String = "取消",
        from vc: UIViewController,
        blurStyle: iOS26AlertBlurStyle = .systemThinMaterial,
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil) {
        let alert = iOS26AlertController(
            title: title,
            message: message,
            actions: [
                iOS26AlertAction(title: cancelTitle, style: .cancel, handler: onCancel),
                iOS26AlertAction(title: confirmTitle, style: .custom(background: UIColor.systemBlue, text: UIColor.white), handler: onConfirm)
            ],
            autoDismiss: true,
            blurStyle: blurStyle
        )
        alert.present(from: vc)
    }
}
