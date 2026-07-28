//
//  DateTimePickerView.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/16.
//

import Foundation
import UIKit

// 代理协议，用于处理选择结果
protocol DateTimePickerDelegate: AnyObject {
func dateTimePicker(_ picker: DateTimePicker, didSelectDate date: Date)
func dateTimePickerDidCancel(_ picker: DateTimePicker)
}

class DateTimePicker: UIView {

// MARK: - 属性
weak var delegate: DateTimePickerDelegate?

private let backgroundView = UIView()
private let contentView = UIView()
private let datePicker = UIDatePicker()
private let toolbar = UIToolbar()

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
  // 背景视图
  backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
  backgroundView.alpha = 0
  let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
  backgroundView.addGestureRecognizer(tapGesture)
  addSubview(backgroundView)
  
  // 内容视图
  contentView.backgroundColor = .systemBackground
  contentView.layer.cornerRadius = 12
  contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
  contentView.clipsToBounds = true
  addSubview(contentView)
  
  // 工具栏
  setupToolbar()
  
  // 日期选择器
  setupDatePicker()
}

private func setupToolbar() {
  toolbar.barTintColor = .systemBackground
  
  let cancelButton = UIBarButtonItem(
      title: "取消".localized,
      style: .plain,
      target: self,
      action: #selector(cancelTapped)
  )
  
  let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
  
  let titleLabel = UILabel()
  titleLabel.text = "选择日期时间".localized
  titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
  titleLabel.textColor = .label
  let titleItem = UIBarButtonItem(customView: titleLabel)
  
  let doneButton = UIBarButtonItem(
      title: "确定".localized,
      style: .done,
      target: self,
      action: #selector(doneTapped)
  )
  
  toolbar.items = [cancelButton, flexibleSpace, titleItem, flexibleSpace, doneButton]
  contentView.addSubview(toolbar)
}

private func setupDatePicker() {
  datePicker.date = selectedDate
  datePicker.datePickerMode = .dateAndTime
  if #available(iOS 13.4, *) {
      datePicker.preferredDatePickerStyle = .wheels
  } else {

  }
  datePicker.locale = Locale.current
  datePicker.minuteInterval = 1
  
  datePicker.maximumDate = Date()
  
  if #available(iOS 13.4, *) {
      datePicker.preferredDatePickerStyle = .wheels
  }
  
  contentView.addSubview(datePicker)
}

private func setupConstraints() {
  backgroundView.translatesAutoresizingMaskIntoConstraints = false
  contentView.translatesAutoresizingMaskIntoConstraints = false
  toolbar.translatesAutoresizingMaskIntoConstraints = false
  datePicker.translatesAutoresizingMaskIntoConstraints = false
  
  NSLayoutConstraint.activate([
      // 背景视图
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      // 内容视图
      contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      // 工具栏
      toolbar.topAnchor.constraint(equalTo: contentView.topAnchor),
      toolbar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      toolbar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      toolbar.heightAnchor.constraint(equalToConstant: 44),
      
      // 日期选择器
      datePicker.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
      datePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      datePicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      datePicker.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      datePicker.heightAnchor.constraint(equalToConstant: 216)
  ])
}

// MARK: - 公共方法
func show(in view: UIView) {
  frame = view.bounds
  view.addSubview(self)
  
  // 初始位置
  contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height)
  
  UIView.animate(withDuration: 0.3) {
      self.backgroundView.alpha = 1
      self.contentView.transform = .identity
  }
}

func hide(completion: (() -> Void)? = nil) {
  UIView.animate(withDuration: 0.3, animations: {
      self.backgroundView.alpha = 0
      self.contentView.transform = CGAffineTransform(translationX: 0, y: self.contentView.bounds.height)
  }) { _ in
      self.removeFromSuperview()
      completion?()
  }
}

func setMinimumDate(_ date: Date?) {
  datePicker.minimumDate = date
}

func setMaximumDate(_ date: Date?) {
  let currentDate = Date()
  if let date = date, date < currentDate {
      datePicker.maximumDate = date
  } else {
      datePicker.maximumDate = currentDate
  }

}

func setSelectedDate(_ date: Date) {
  let currentDate = Date()
  selectedDate = date > currentDate ? currentDate : date
  datePicker.date = selectedDate
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
  selectedDate = datePicker.date
  hide {
      self.delegate?.dateTimePicker(self, didSelectDate: self.selectedDate)
  }
}
}

