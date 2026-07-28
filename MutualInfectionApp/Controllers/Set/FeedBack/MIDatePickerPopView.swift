//
//  MIDatePickerPopView.swift
//  MutualInfectionApp
//
//  Created by delegate on 2025/10/15.
//

import UIKit

class MIDatePickerPopView: UIView {
    private var year: Int = 0;
    private var month: Int = 0;
    private var day: Int = 0;
    private var hour: Int = 0;
    private var minute: Int = 0;
    
    // 回调闭包，当选择发生变化时调用
    var onDateSelected: ((_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Void)?
    var onDateObjectSelected: ((_ date: Date) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = CGRectMake(0, 0, ksUIScreenW, ksUIScreenH)
        self.backgroundColor = .black
        self.alpha = 0.7
        addSubview(bgView)
        
        [cancelButton, sureButton, datePickerView].forEach {
            bgView.addSubview($0)
        }
        bgView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
        }
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.leading.equalTo(10)
            make.height.equalTo(30)
        }
        sureButton.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.centerY.equalTo(cancelButton.snp.centerY)
            make.height.equalTo(30)
        }
        datePickerView.snp.makeConstraints { make in
            make.top.equalTo(cancelButton.snp.bottom).offset(10)
            make.bottom.equalToSuperview().offset(-100)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelButtonAction() {
        removeFromSuperview()
    }
    
    @objc private func sureButtonAction() {
        if year + month + day + hour + minute == 0 {
            let currentDate = Date()
            let calendar = Calendar.current
            // 1. 从 Date 中提取 年、月、日、时、分
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            let day = calendar.component(.day, from: currentDate)
            let hour = calendar.component(.hour, from: currentDate)
            let minute = calendar.component(.minute, from: currentDate)
            onDateObjectSelected?(currentDate)
            onDateSelected?(year, month, day, hour, minute)
            
        }else {
            let calendar = Calendar.current
            let dateComponents = DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
            // 安全创建 Date（避免极端情况导致 nil）
            if let selectedDate = calendar.date(from: dateComponents) {
                onDateObjectSelected?(selectedDate) // 触发 Date 回调
            }
            onDateSelected?(year, month, day, hour, minute)
        }
        cancelButtonAction()
    }
    
    //=================================================================
    //                            lazy
    //=================================================================
    // MARK: - lazy
    private lazy var bgView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("取消", for: .normal)
        button.setTitle("取消", for: .selected)
        button.setTitleColor(UIColor(hex: "#666666"), for: .normal)
        button.setTitleColor(UIColor(hex: "#666666"), for: .selected)
        button.titleLabel?.font = pingFangSC(16)
        button.addTarget(self, action: #selector(cancelButtonAction), for: .touchUpInside)
        return button
    }()
    private lazy var sureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("确定", for: .normal)
        button.setTitle("确定", for: .selected)
        button.setTitleColor(UIColor.blue, for: .normal)
        button.setTitleColor(UIColor.blue, for: .selected)
        button.titleLabel?.font = pingFangSC(16)
        button.addTarget(self, action: #selector(sureButtonAction), for: .touchUpInside)
        return button
    }()
    private lazy var datePickerView: MIDatePickerView = {
        let pickerView = MIDatePickerView(frame: .zero)
        
        pickerView.onDateSelected = { [weak self] in
            print("\($0) - \($1) - \($2) - \($3) - \($4)")
            self?.year = $0
            self?.month = $1
            self?.day = $2
            self?.hour = $3
            self?.minute = $4
        }
        return pickerView
    }()
}
