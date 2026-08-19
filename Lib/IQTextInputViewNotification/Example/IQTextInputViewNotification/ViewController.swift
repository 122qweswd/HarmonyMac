//
//  ViewController.swift
//  IQTextInputViewNotification
//
//  Created by hackiftekhar on 07/22/2024.
//  Copyright (c) 2024 hackiftekhar. All rights reserved.
//

import UIKit
import IQTextInputViewNotification

class ViewController: UIViewController {

    private let textInputViewObserver: IQTextInputViewNotification = .init()

    @IBAction private func subscribeAction(_ sender: UIBarButtonItem) {

        let identifier: String = "NotificationIdentifier"

        if textInputViewObserver.isSubscribed(identifier: identifier) {
            sender.title = "Subscribe"
            textInputViewObserver.unsubscribe(identifier: identifier)
            textInputViewObserver.textInputView?.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        } else {
            sender.title = "Unsubscribe"
            textInputViewObserver.subscribe(identifier: identifier) { event, textInputView in
                print(event.name, ":", textInputView)

                switch event {
                case .beginEditing:
                    textInputView.backgroundColor = UIColor(named: "FBBC05")
                case .endEditing:
                    textInputView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                }
            }
        }
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
