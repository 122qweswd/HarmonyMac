//
//  MITransferHistoryTransferTypeView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/10/31.
//

import UIKit
import SnapKit

class MITransferHistoryTransferTypeView: UIView {
    
    let receiveButton = NotHighlightButton()
    let sendButton = NotHighlightButton()
    let selectionIndicator = UIView()
    var indicatorLeadingConstraint: Constraint?

    var receiveCallBack: ClickBlockVoid?
    var sendCallBack: ClickBlockVoid?
     
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .white
        
        layer.cornerRadius = 22
        layer.shadowColor = "#000000".color.withAlpha(0.15).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 12
        
        initView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initView() {
        // 选中指示块（位于按钮之下）
        selectionIndicator.backgroundColor = "#336FFF".color
        selectionIndicator.layer.cornerRadius = 16
        selectionIndicator.isUserInteractionEnabled = false
        self.addSubview(selectionIndicator)
        selectionIndicator.snp.makeConstraints { make in
            indicatorLeadingConstraint = make.leading.equalToSuperview().offset(4).constraint
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 88, height: 32))
        }

        // 我接收的
        receiveButton.setTitle("我接收的", for: .normal)
        receiveButton.isSelected = true
        receiveButton.setTitleColor("#000000".color, for: .normal)
        receiveButton.setTitleColor(.white, for: .selected)
        receiveButton.titleLabel?.font = pingFangSC(13, weight: .regular)
        receiveButton.contentHorizontalAlignment = .center
        receiveButton.addClickClosure { [weak self] sender in
            self?.receiveCallBack?()
            self?.refreshButtonStatus(button: self?.receiveButton, select: true)
            self?.refreshButtonStatus(button: self?.sendButton, select: false)
            self?.updateButtons(selectedIndex: 0)
        }
        
        /// 我发送的
        sendButton.setTitle("我发送的", for: .normal)
        sendButton.setTitleColor("#000000".color, for: .normal)
        sendButton.setTitleColor(.white, for: .selected)
        sendButton.titleLabel?.font = pingFangSC(13, weight: .regular)
        sendButton.contentHorizontalAlignment = .center
        sendButton.addClickClosure { [weak self] sender in
            self?.sendCallBack?()
            self?.refreshButtonStatus(button: self?.sendButton, select: true)
            self?.refreshButtonStatus(button: self?.receiveButton, select: false)
            self?.updateButtons(selectedIndex: 1)
        }

        let stack = UIStackView(arrangedSubviews: [receiveButton, sendButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 0
        self.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func refreshButtonStatus(button: UIButton?, select: Bool) {
        if select {
            button?.titleLabel?.font = pingFangSC(13, weight: .medium)
        } else {
            button?.titleLabel?.font = pingFangSC(13, weight: .regular)
        }
    }
    
    private func updateButtons(selectedIndex index: Int) {
        let isReceive = index == 0
        receiveButton.isSelected = isReceive
        sendButton.isSelected = !isReceive

        // 指示块移动动画（左边距：4 或 176 - 4 - 88 = 84）
        let leftOffset: CGFloat = isReceive ? 4 : 84
        indicatorLeadingConstraint?.update(offset: leftOffset)
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: {
            self.layoutIfNeeded()
        })
    }
    
}
