//
//  MITransferHistoryContenrController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/12.
//

import Foundation
import UIKit
import SnapKit
import Hero

class MITransferHistoryContenrController: MIBaseHistoryViewController {
    
    // MARK: - Paging
    private var pageViewController: UIPageViewController?
    private var orderedControllers: [MITransferHistoryListController] = []
    private var currentIndex: Int = 0

    // MARK: - Bottom Switch View
    private let bottomSwitchContainer = UIView()
    private let receiveButton = NotHighlightButton()
    private let sendButton = NotHighlightButton()
    private let selectionIndicator = UIView()
    private var indicatorLeadingConstraint: Constraint?
    
    /// 当前控制器
    override var currentController: MITransferHistoryListController? { orderedControllers[currentIndex] }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initViews()
        setupPages()
        setupBottomSwitchView()
    }
    
    func initViews() {
        
        #if DEBUG
        let tap = UITapGestureRecognizer(target: self, action: #selector(configTestData))
        self.navigationView?.titleLabel.isUserInteractionEnabled = true
        self.navigationView?.titleLabel.addGestureRecognizer(tap)
        #endif
        
        self.navigationView?.lineView.isHidden = true
    }
     
    @objc func configTestData() {
        Task {
            await WCDBTestManager.shared.runCompleteTestSuite()
        }
    }
    
    // MARK: - Setup Pages
    private func setupPages() {
        let receiveVC = MITransferHistoryListController()
        receiveVC.transferType = .receive
        receiveVC.viewModel.didSelectAction = { [weak self] in
            guard let self = self else { return }
            
            updateSelectAllBtn(isSelectAll: receiveVC.viewModel.isSelectAll)
        }
        
        let sendVC = MITransferHistoryListController()
        sendVC.transferType = .send
        sendVC.viewModel.didSelectAction = { [weak self] in
            guard let self = self else { return }
            
            updateSelectAllBtn(isSelectAll: receiveVC.viewModel.isSelectAll)
        }
        
        orderedControllers = [receiveVC, sendVC]

        let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([receiveVC], direction: .forward, animated: false)
        self.pageViewController = pageVC

        addChild(pageVC)
        contentView.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)

        // 布局：填充除底部悬浮按钮区域外
        pageVC.view.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalToSuperview() // 浮层以 overlay 方式覆盖
        }
    }

    // MARK: - Bottom Switch View
    private func setupBottomSwitchView() {
        bottomSwitchContainer.backgroundColor = UIColor.white
        bottomSwitchContainer.layer.cornerRadius = 29
        bottomSwitchContainer.layer.masksToBounds = false
        bottomSwitchContainer.layer.shadowColor = "#000000".color.withAlpha(0.15).cgColor
        bottomSwitchContainer.layer.shadowOpacity = 1
        bottomSwitchContainer.layer.shadowOffset = CGSize(width: 0, height: 6)
        bottomSwitchContainer.layer.shadowRadius = 12

        view.addSubview(bottomSwitchContainer)
        bottomSwitchContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-10)
            make.height.equalTo(58)
            make.width.equalTo(174)
        }

        // 选中指示块（位于按钮之下）
        selectionIndicator.backgroundColor = "#787880".color.withAlpha(0.16)
        selectionIndicator.layer.cornerRadius = 25
        selectionIndicator.isUserInteractionEnabled = false
        bottomSwitchContainer.addSubview(selectionIndicator)
        selectionIndicator.snp.makeConstraints { make in
            indicatorLeadingConstraint = make.leading.equalTo(bottomSwitchContainer).offset(4).constraint
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 86, height: 50))
        }

        // 我接收的
        receiveButton.setTitle(LocalizedStrings.iReceived, for: .normal)
        receiveButton.setImage(UIImage.iconReceiveNormal, for: .normal)
        receiveButton.setImage(UIImage.iconReceiveSelect, for: .selected)
        receiveButton.setTitleColor("#000000".color.withAlpha(0.9), for: .normal)
        receiveButton.setTitleColor("#0191FF".color, for: .selected)
        receiveButton.titleLabel?.font = pingFangSC(10, weight: .medium)
        receiveButton.contentHorizontalAlignment = .center
        receiveButton.addTarget(self, action: #selector(didTapReceive), for: .touchUpInside)

        /// 我发送的
        sendButton.setTitle(LocalizedStrings.iSent, for: .normal)
        sendButton.setImage(UIImage.iconSendNormal, for: .normal)
        sendButton.setImage(UIImage.iconSendSelect, for: .selected)
        sendButton.setTitleColor("#000000".color.withAlpha(0.9), for: .normal)
        sendButton.setTitleColor("#0191FF".color, for: .selected)
        sendButton.titleLabel?.font = pingFangSC(10, weight: .medium)
        sendButton.contentHorizontalAlignment = .center
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [receiveButton, sendButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 0
        bottomSwitchContainer.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        }
        // 初始状态
        updateButtons(selectedIndex: currentIndex)
        // 将图标置于上方，文字在下方且不换行
        layoutButtonsImageTop()
    }

    private func updateButtons(selectedIndex index: Int) {
        let isReceive = index == 0
        receiveButton.isSelected = isReceive
        sendButton.isSelected = !isReceive

        // 指示块移动动画（左边距：4 或 174-4-86 = 84）
        let leftOffset: CGFloat = isReceive ? 4 : 84
        indicatorLeadingConstraint?.update(offset: leftOffset)
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: {
            self.bottomSwitchContainer.layoutIfNeeded()
        })
    }
    
    /// 刷新Edit状态UI展示
    override func configEditStatusUI(isEdit: Bool) {
        super.configEditStatusUI(isEdit: isEdit)
        bottomSwitchContainer.isHidden = isEdit
    }

    // MARK: - Actions
    @objc private func didTapReceive() {
        setPage(index: 0, animated: true)
    }

    @objc private func didTapSend() {
        setPage(index: 1, animated: true)
    }

    private func setPage(index: Int, animated: Bool) {
        guard index >= 0, index < orderedControllers.count, let pageVC = pageViewController else { return }
        let direction: UIPageViewController.NavigationDirection = index >= currentIndex ? .forward : .reverse
        pageVC.setViewControllers([orderedControllers[index]], direction: direction, animated: animated)
        currentIndex = index
        updateButtons(selectedIndex: index)
    }
    
}



extension MITransferHistoryContenrController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        /**
        guard let vc = viewController as? MITransferHistoryListController, let idx = orderedControllers.firstIndex(of: vc) else { return nil }
        let before = idx - 1
        return before >= 0 ? orderedControllers[before] : nil
         */
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        /**
        guard let vc = viewController as? MITransferHistoryListController, let idx = orderedControllers.firstIndex(of: vc) else { return nil }
        let after = idx + 1
        return after < orderedControllers.count ? orderedControllers[after] : nil
         */
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let visible = pageViewController.viewControllers?.first as? MITransferHistoryListController, let idx = orderedControllers.firstIndex(of: visible) else { return }
        currentIndex = idx
        updateButtons(selectedIndex: idx)
    }
}

// MARK: - Layout helpers
extension MITransferHistoryContenrController {
    private func layoutButtonsImageTop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            func apply(_ button: UIButton) {
                guard let imageSize = button.imageView?.image?.size, let titleSize = button.titleLabel?.intrinsicContentSize else { return }
                let totalHeight = imageSize.height + 2 + titleSize.height
                button.imageEdgeInsets = UIEdgeInsets(top: -(totalHeight - imageSize.height), left: 0, bottom: 0, right: -titleSize.width)
                button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -imageSize.width, bottom: -(totalHeight - titleSize.height), right: 0)
                button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
            }
            apply(self.receiveButton)
            apply(self.sendButton)
        }
    }
}
