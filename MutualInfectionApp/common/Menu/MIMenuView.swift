//
//  MIMenuView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/15.
//

import Foundation
import UIKit
import SnapKit

protocol MIMenuViewDelegate: AnyObject {
    
    /// 点击事件回调
    /// - Parameters:
    ///   - menuView: menuView
    ///   - item: 点击行
    ///   - index: 行号
    func menuView(_ menuView: MIMenuView, didSelectItem item: MIMenuItemConfig, at index: Int)
    
    /// 关闭回调
    /// - Parameter menuView: menuView
    func menuViewDidDismiss(_ menuView: MIMenuView)
}

class MIMenuView: UIView {
    
    /// 弹窗代理
    weak var delegate: MIMenuViewDelegate?
    
    /// 弹窗配置
    private var config: MIMenuConfig = MIMenuConfig()
    
    /// 背景遮罩
    private let backgroundView = UIView()
    
    /// 容器视图
    private let containerView = UIView()
    
    /// 列表视图
    private let tableView = UITableView()
    
    private var heightConstraint: Constraint?
    private var widthConstraint: Constraint?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    
    
    // MARK: - Public Methods
    
    /// 显示弹窗
    /// - Parameters:
    ///   - items: 菜单项数组
    ///   - config: 弹窗配置
    ///   - fromView: 锚点视图（可选）
    func show(config: MIMenuConfig, fromView: UIView? = nil) {
        self.config = config
        
        updateConfig()
        calculateAndUpdateSize()
        
        // 添加到窗口
        if let window = MIKeyWindow {
            window.addSubview(self)
            self.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        // 动画显示
        showWithAnimation()
    }
    
    /// 隐藏弹窗
    func dismiss() {
        hideWithAnimation { [weak self] in
            self?.removeFromSuperview()
            self?.delegate?.menuViewDidDismiss(self!)
        }
    }
     
    private func calculateAndUpdateSize() {
        //let itemCount = config.listData.count
        //let maxRows = min(config.maxRows, itemCount)
        
        let itemTotalHeight = config.listData.map { $0.rowHeight ?? 0 }.reduce(CGFloat(0), +)
        
        let totalHeight = itemTotalHeight + config.contentInsets.top + config.contentInsets.bottom
        
        heightConstraint?.update(offset: totalHeight)
        
        // 设置表格视图的行高
        tableView.rowHeight = config.rowHeight
    }
    
    private func showWithAnimation() {
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.backgroundView.alpha = 1
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        }
    }
    
    private func hideWithAnimation(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.backgroundView.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            if !containerView.frame.contains(location) {
                dismiss()
            }
        }
    }
}

// MARK: -  UI
extension MIMenuView {
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // 背景遮罩
        backgroundView.backgroundColor = UIColor.black.withAlpha(0.1)
        backgroundView.alpha = 0
        addSubview(backgroundView)
        addSubview(containerView)
        
        // 表格视图
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(MIMenuCell.self, forCellReuseIdentifier: MIMenuCell.className)
        containerView.addSubview(tableView)
        
        setupConstraints()
        
        updateConfig()
    }
    
    // MARK: - Private Methods
    
    private func updateConfig() {
        // 容器视图
        containerView.backgroundColor = config.backgroundColor
        containerView.layer.cornerRadius = config.cornerRadius
        containerView.layer.masksToBounds = false
        /// 设置阴影
        containerView.layer.shadowColor = config.shadowConfig.color.cgColor
        containerView.layer.shadowOffset = config.shadowConfig.offset
        containerView.layer.shadowRadius = config.shadowConfig.radius
        containerView.layer.shadowOpacity = config.shadowConfig.opacity
        
        widthConstraint?.update(offset: config.width)
        
        tableView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(config.contentInsets)
        }
    }
    
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(MISafeAreaTop + 70)
            make.trailing.equalToSuperview().offset(-16)
            widthConstraint = make.width.equalTo(config.width).constraint
            heightConstraint = make.height.equalTo(0).constraint
        }
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(config.contentInsets)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension MIMenuView: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return config.listData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MIMenuCell.className, for: indexPath) as? MIMenuCell else {
            return UITableViewCell()
        }
        
        let item = config.listData[indexPath.row]
        let isLastItem = indexPath.row == config.listData.count - 1
        cell.configure(with: item, separatorConfig: config.separatorConfig, isLastItem: isLastItem)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = config.listData[indexPath.row]
        
        MIMenuConfig.updateSelectConfig(selectConfig: item, menuConig: config)
        
        delegate?.menuView(self, didSelectItem: item, at: indexPath.row)
        dismiss()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = config.listData[indexPath.row]
        return item.rowHeight ?? config.rowHeight
    }
}
