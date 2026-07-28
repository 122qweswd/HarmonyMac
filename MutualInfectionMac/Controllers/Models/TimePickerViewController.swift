//
//  TimePickerViewController.swift
//  MutualInfectionMac
//
//  Created by luchao on 2025/11/6.
//

import Foundation
import AppKit

// 代理协议，用于处理选择结果
protocol MacDateTimePickerDelegate: AnyObject {
    func dateTimePicker(_ picker: MacDateTimePicker, didSelectDate date: Date)
    func dateTimePickerDidCancel(_ picker: MacDateTimePicker)
}

class MacDateTimePicker: NSView {
    
    // MARK: - 属性
    weak var delegate: MacDateTimePickerDelegate?
    private let backgroundView = NSView()
    private let contentView = NSView()
    private let datePicker = NSDatePicker()
    private let toolbar = NSView()
    private var selectedDate: Date
    
    // MARK: - 初始化
    init(selectedDate: Date = Date()) {
        self.selectedDate = selectedDate
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        self.selectedDate = Date()
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    // MARK: - UI设置
    private func setupUI() {
        wantsLayer = true
        
        // 背景视图
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        backgroundView.alphaValue = 0
        
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tapGesture)
        addSubview(backgroundView)
        
        // 内容视图
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(contentView)
        
        // 工具栏
        setupToolbar()
        
        // 日期选择器
        setupDatePicker()
    }
    
    private func setupToolbar() {
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 取消按钮
        let cancelButton = NSButton(title: "取消".localized, target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addCustomMarqueeLabel()
        toolbar.addSubview(cancelButton)
        
        // 标题
        let titleLabel = MIMacMarqueeTextField.getCommonMacMarqueeTextField()
        titleLabel.backgroundColor = NSColor.white
        titleLabel.font = .mi.pingFangSCSemibold(size: 16)
        titleLabel.textColor = .mi.hex("＃336FFF")
        titleLabel.stringValue = "选择日期时间".localized
        titleLabel.alignment = .center
        titleLabel.resetScrollOnTextChange = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false        
        toolbar.addSubview(titleLabel)
        
        // 确定按钮
        let doneButton = NSButton(title: "确定".localized, target: self, action: #selector(doneTapped))
        doneButton.bezelStyle = .rounded
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addCustomMarqueeLabel()
        toolbar.addSubview(doneButton)
        
        // 工具栏约束
        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(toolbar).offset(16)
            make.centerY.equalTo(toolbar)
            make.width.equalTo(60)
        }

        titleLabel.snp.makeConstraints { make in
            make.center.equalTo(toolbar)
            make.leading.equalTo(toolbar).offset(76)
            make.trailing.equalTo(toolbar).offset(-76)
            make.height.equalTo(30)
        }

        doneButton.snp.makeConstraints { make in
            make.trailing.equalTo(toolbar).offset(-16)
            make.centerY.equalTo(toolbar)
            make.width.equalTo(60)
        }
        
        contentView.addSubview(toolbar)
    }
    
    private func setupDatePicker() {
        datePicker.dateValue = selectedDate
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.datePickerMode = .single
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
//        datePicker.locale = Locale(identifier: "zh_CN")
        datePicker.locale = Locale.current
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(datePicker)
    }
    
    private func setupConstraints() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // 背景视图约束
        backgroundView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.leading.equalTo(self)
            make.trailing.equalTo(self)
            make.bottom.equalTo(self)
        }
        
        // 内容视图约束
        contentView.snp.makeConstraints { make in
            make.leading.equalTo(self)
            make.trailing.equalTo(self)
            make.bottom.equalTo(self)
            make.height.equalTo(260)
        }
        
        // 工具栏约束
        toolbar.snp.makeConstraints { make in
            make.top.equalTo(contentView)
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
            make.height.equalTo(44)
        }
        
        // 日期选择器约束
        datePicker.snp.makeConstraints { make in
            make.top.equalTo(toolbar.snp.bottom).offset(20)
            make.leading.equalTo(contentView).offset(20)
            make.trailing.equalTo(contentView).offset(-20)
            make.bottom.equalTo(contentView).offset(-20)
        }
    }
    
    // MARK: - 公共方法
    func show(in view: NSView) {
        frame = view.bounds
        view.addSubview(self)
        
        // 初始位置动画
        contentView.alphaValue = 0
        contentView.frame.origin.y += contentView.frame.height
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.backgroundView.animator().alphaValue = 1
            self.contentView.animator().alphaValue = 1
            self.contentView.animator().frame.origin.y -= self.contentView.frame.height
        }
    }
    
    func hide(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.backgroundView.animator().alphaValue = 0
            self.contentView.animator().alphaValue = 0
            self.contentView.animator().frame.origin.y += self.contentView.frame.height
        }) {
            self.removeFromSuperview()
            completion?()
        }
    }
    
    func setMinimumDate(_ date: Date?) {
        datePicker.minDate = date
    }
    
    func setMaximumDate(_ date: Date?) {
        let currentDate = Date()
        if let date = date, date < currentDate {
            datePicker.maxDate = date
        } else {
            datePicker.maxDate = currentDate
        }
    }
    
    func setSelectedDate(_ date: Date) {
        let currentDate = Date()
        selectedDate = date > currentDate ? currentDate : date
        datePicker.dateValue = selectedDate
    }
    
    // MARK: - 动作处理
    @objc private func backgroundTapped() {
        cancelTapped()
    }
    
    @objc private func cancelTapped() {
        hide {
            self.delegate?.dateTimePickerDidCancel(self)
        }
    }
    
    @objc private func doneTapped() {
        selectedDate = datePicker.dateValue
        hide {
            self.delegate?.dateTimePicker(self, didSelectDate: self.selectedDate)
        }
    }
}
