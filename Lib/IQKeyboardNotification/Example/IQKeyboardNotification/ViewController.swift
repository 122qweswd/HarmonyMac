//
//  ViewController.swift
//  IQKeyboardNotification
//
//  Created by hackiftekhar on 07/21/2024.
//  Copyright (c) 2024 hackiftekhar. All rights reserved.
//

import UIKit
import IQKeyboardNotification

class ViewController: UIViewController {

    private let keyboard: IQKeyboardNotification = .init()

    @IBOutlet private var eventLabel: UILabel!
    @IBOutlet private var isVisibleLabel: UILabel!
    @IBOutlet private var beginFrameLabel: UILabel!
    @IBOutlet private var endFrameLabel: UILabel!
    @IBOutlet private var animationDurationLabel: UILabel!
    @IBOutlet private var animationCurveLabel: UILabel!
    @IBOutlet private var isLocalLabel: UILabel!
    @IBOutlet private var scrollViewBottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateKeyboardInfo()
    }

    @IBAction private func subscribeAction(_ sender: UIBarButtonItem) {

        let identifier: String = "NotificationIdentifier"

        if keyboard.isSubscribed(identifier: identifier) {
            sender.title = "Subscribe"
            keyboard.unsubscribe(identifier: identifier)
        } else {
            sender.title = "Unsubscribe"
//            keyboard.subscribe(for: [.willChangeFrame, .didChangeFrame], identifier: identifier) { event, size in
            keyboard.subscribe(identifier: identifier) { event, size in
                print(event.notification.rawValue, ":", size)
                self.updateKeyboardInfo()
                self.updateScrollViewPosition()
            }
        }
    }

    private func updateScrollViewPosition() {
        keyboard.animate {
            switch self.keyboard.keyboardInfo.event {

            case .willShow:
                self.view.backgroundColor = UIColor(named: "FBBC05")
            case .didShow:
                self.view.backgroundColor = UIColor(named: "34A853")
            case .willChangeFrame:
                self.view.backgroundColor = UIColor(named: "E80B26")
            case .didChangeFrame:
                self.view.backgroundColor = UIColor(named: "0166FF")
            case .willHide:
                self.view.backgroundColor = UIColor(named: "FBBC05")
            case .didHide:
                self.view.backgroundColor = UIColor(named: "F58220")
            }

            self.scrollViewBottomConstraint.constant = self.keyboard.frame.height
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func updateKeyboardInfo() {
        let keyboardInfo = keyboard.keyboardInfo
        eventLabel.text = keyboardInfo.event.notification.rawValue
        isVisibleLabel.text = keyboardInfo.isVisible ? "Yes" : "No"
        beginFrameLabel.text = keyboardInfo.beginFrame.debugDescription
        endFrameLabel.text = keyboardInfo.endFrame.debugDescription
        animationDurationLabel.text = keyboardInfo.animationDuration.description
        animationCurveLabel.text = "\(keyboardInfo.animationCurve.rawValue)"
        isLocalLabel.text = keyboardInfo.isLocal ? "Yes" : "No"
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

extension ViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
