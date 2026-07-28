//
//  MIDatePickerView.swift
//  MutualInfectionApp
//
//  Created by delegate on 2025/10/15.
//

import UIKit

class MIDatePickerView: UIView {
    // MARK: - 可外部配置属性
    /// 未选中文字颜色
    var textColor: UIColor = .darkGray {
        didSet { pickerView.reloadAllComponents() }
    }
    /// 选中文字颜色
    var selectedTextColor: UIColor = .black {
        didSet { pickerView.reloadAllComponents() }
    }
    /// 选中回调（返回年、月、日、时、分）
    var onDateSelected: ((_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Void)?
    var onDateObjectSelected: ((_ date: Date) -> Void)?
    // MARK: - 私有属性（5个组件：年、月、日、时、分）
    private let pickerView = UIPickerView()
    private var years: [Int] = []       // 年数据
    private var months: [Int] = Array(1...12) // 月数据（固定1-12）
    private var days: [Int] = []        // 日数据（随年月动态变）
    private var hours: [Int] = Array(0...23)  // 时数据（固定0-23）
    private var minutes: [Int] = Array(0...59) // 分数据（固定0-59）
    
    // 选中值
    var selectedYear: Int = 0
    var selectedMonth: Int = 0
    var selectedDay: Int = 0
    var selectedHour: Int = 0
    var selectedMinute: Int = 0
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupData()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupData()
        setupConstraints()
    }
}

// MARK: - 基础设置（UI + 数据）
extension MIDatePickerView {
    private func setupView() {
        backgroundColor = .white
        pickerView.dataSource = self
        pickerView.delegate = self
        pickerView.backgroundColor = .clear
        addSubview(pickerView)
    }
    
    private func setupData() {
        let currentDate = Date()
        let calendar = Calendar.current
        
        // 1. 年数据：最近30年（如2025-1995）
        let currentYear = calendar.component(.year, from: currentDate)
        years = (currentYear - 30 ... currentYear).reversed().map { $0 }
        
        // 2. 初始选中当前时间
        selectedYear = currentYear
        selectedMonth = calendar.component(.month, from: currentDate)
        selectedHour = calendar.component(.hour, from: currentDate)
        selectedMinute = calendar.component(.minute, from: currentDate)
        
        // 3. 动态计算日数据（根据年月）
        updateDays()
        // 确保日选中值有效
        let currentDay = calendar.component(.day, from: currentDate)
        selectedDay = min(currentDay, days.count)
        
        // 4. 设置初始选中行
        setInitialSelectedRows()
    }
    
    private func setupConstraints() {
        pickerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(320) // 与你之前设置的高度一致
        }
    }
}

// MARK: - 数据联动（日数据随年月变化）
extension MIDatePickerView {
    /// 根据选中的年、月，更新日数据（处理闰年、小月）
    private func updateDays() {
        let calendar = Calendar.current
        var components = DateComponents(year: selectedYear, month: selectedMonth)
        components.day = 1 // 确保月份有效
        
        // 安全计算当月天数
        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            days = Array(1...31) // 异常情况默认31天
            return
        }
        days = Array(1...dayRange.count)
    }
    
    /// 设置初始选中行（匹配当前时间）
    private func setInitialSelectedRows() {
        // 年：找到当前年的索引
        if let yearIndex = years.firstIndex(of: selectedYear) {
            pickerView.selectRow(yearIndex, inComponent: 0, animated: false)
        }
        // 月：索引=月份-1（如1月对应索引0）
        pickerView.selectRow(selectedMonth - 1, inComponent: 1, animated: false)
        // 日：找到当前日的索引
        if let dayIndex = days.firstIndex(of: selectedDay) {
            pickerView.selectRow(dayIndex, inComponent: 2, animated: false)
        }
        // 时：索引=小时（如14点对应索引14）
        pickerView.selectRow(selectedHour, inComponent: 3, animated: false)
        // 分：索引=分钟（如30分对应索引30）
        pickerView.selectRow(selectedMinute, inComponent: 4, animated: false)
    }
}

// MARK: - UIPickerView 代理（控制显示和选中逻辑）
extension MIDatePickerView: UIPickerViewDataSource, UIPickerViewDelegate {
    /// 组件数量：5个（年、月、日、时、分）
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 5
    }
    
    /// 每个组件的行数
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return years.count    // 年
        case 1: return months.count   // 月
        case 2: return days.count     // 日
        case 3: return hours.count    // 时
        case 4: return minutes.count  // 分
        default: return 0
        }
    }
    
    /// 每个组件的宽度（平均分配，5个组件各占1/5）
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return UIScreen.main.bounds.size.width / 5
    }
    /*
    /// 显示内容（自定义文字格式，如“2025年”“10月”）
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let text: String
        switch component {
        case 0: text = "\(years[row])"
        case 1: text = "\(months[row])月"
        case 2: text = "\(days[row])日"
        case 3: text = "\(hours[row])时"
        case 4: text = "\(minutes[row])分"
        default: text = ""
        }
        
        // 区分选中/未选中状态（颜色+字重）
        let isSelected = pickerView.selectedRow(inComponent: component) == row
        let color = isSelected ? selectedTextColor : textColor
        let font = UIFont.systemFont(ofSize: 10, weight: isSelected ? .medium : .regular)
        
        return NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: font
        ])
    }
    */
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let text: String
        switch component {
        case 0: text = "\(years[row])年"
        case 1: text = "\(months[row])月"
        case 2: text = "\(days[row])日"
        case 3: text = "\(hours[row])时"
        case 4: text = "\(minutes[row])分"
        default: text = ""
        }
        let isSelected = pickerView.selectedRow(inComponent: component) == row
        let color = isSelected ? selectedTextColor : textColor
        let font = UIFont.systemFont(ofSize: 16, weight: isSelected ? .medium : .regular)
        
        var fontLabel: UILabel? = nil
        if let cell = view as? UILabel {
            cell.text = text
            cell.textColor = color
            cell.font = font
            cell.textAlignment = .center
        }
        fontLabel = UILabel()
        fontLabel?.text = text
        fontLabel?.textColor = color
        fontLabel?.font = font
        fontLabel?.textAlignment = .center
        return fontLabel!
    }
    /// 选中行逻辑（更新选中值+联动数据）
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0: // 年选中
            selectedYear = years[row]
            updateDays() // 年变了，更新日数据
            pickerView.reloadComponent(2) // 刷新日组件
            // 确保日选中值有效
            if selectedDay > days.count {
                selectedDay = days.count
                pickerView.selectRow(days.count - 1, inComponent: 2, animated: true)
            }
        case 1: // 月选中
            selectedMonth = months[row]
            updateDays() // 月变了，更新日数据
            pickerView.reloadComponent(2) // 刷新日组件
            // 确保日选中值有效
            if selectedDay > days.count {
                selectedDay = days.count
                pickerView.selectRow(days.count - 1, inComponent: 2, animated: true)
            }
        case 2: // 日选中
            selectedDay = days[row]
        case 3: // 时选中
            selectedHour = hours[row]
        case 4: // 分选中
            selectedMinute = minutes[row]
        default: break
        }
        let calendar = Calendar.current
        let dateComponents = DateComponents(
            year: selectedYear,
            month: selectedMonth,
            day: selectedDay,
            hour: selectedHour,
            minute: selectedMinute
            // 时区默认使用当前时区（与系统一致，无需额外设置）
        )
        // 安全创建 Date（避免极端情况导致 nil）
        if let selectedDate = calendar.date(from: dateComponents) {
            onDateObjectSelected?(selectedDate) // 触发 Date 回调
        }
        // 触发回调，返回选中的年月日时分
        onDateSelected?(selectedYear, selectedMonth, selectedDay, selectedHour, selectedMinute)
    }
}
