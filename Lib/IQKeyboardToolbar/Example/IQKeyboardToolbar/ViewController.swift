//
//  ViewController.swift
//  IQKeyboardToolbar
//
//  Created by hackiftekhar on 07/23/2024.
//  Copyright (c) 2024 hackiftekhar. All rights reserved.
//

import UIKit
import IQKeyboardToolbar

class ViewController: UIViewController {

    @IBOutlet private var textField1: UITextField!
    @IBOutlet private var textView1: UITextView!
    @IBOutlet private var textField2: UITextField!
    @IBOutlet private var textView2: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Previous Next and Done button
        textField1.iq.addPreviousNextDone(target: self,
                                          previousAction: #selector(textField1PreviousAction),
                                          nextAction: #selector(textField1NextAction),
                                          doneAction: #selector(doneAction), showPlaceholder: true)

        // Add Previous Next and Right button with customized titles or images
        textView1.iq.addPreviousNextRight(target: self,
                                          previousConfiguration: .init(title: "Prev",
                                                                       action: #selector(textView1PreviousAction)),
                                          nextConfiguration: .init(title: "Next",
                                                                   action: #selector(textView1NextAction)),
                                          rightConfiguration: .init(image: UIImage(systemName: "chevron.down")!,
                                                                    action: #selector(doneAction)),
                                          title: "Text View 1")

        textField2.iq.addDone(target: self,
                              action: #selector(doneAction),
                              title: "Select Account")

        // Add an action to the title
        textField2.iq.toolbar.titleBarButton.setTarget(self,
                                                       action: #selector(selectAccount))

        // Add additional leading and trailing items
        textView2.iq.toolbar.additionalLeadingItems = [.init(barButtonSystemItem: .add,
                                                             target: self,
                                                             action: #selector(addAction))]
        textView2.iq.toolbar.additionalTrailingItems = [.init(barButtonSystemItem: .camera,
                                                              target: self, action:
                                                                #selector(cameraAction))]
        textView2.iq.addToolbar(target: self,
                                previousConfiguration: nil,
                                nextConfiguration: .init(title: "Next", action: #selector(doneAction)),
                                rightConfiguration: .init(title: "Finish", action: #selector(doneAction)),
                                title: "TextView 2")
    }

    @IBAction private func doneAction() {
        self.view.endEditing(true)
    }

    @objc func addAction() {
        let alertController = UIAlertController(title: "Plus Action",
                                                message: "You tapped on Plus", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        alertController.popoverPresentationController?.sourceView = textField2
        self.present(alertController, animated: true, completion: nil)
    }

    @objc func cameraAction() {
        let alertController = UIAlertController(title: "Camera Action",
                                                message: "You tapped on Camera", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        alertController.popoverPresentationController?.sourceView = textField2
        self.present(alertController, animated: true, completion: nil)
    }

    @objc func selectAccount() {

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alertController.addAction(UIAlertAction(title: "test@example.com",
                                                style: .default,
                                                handler: { (_: UIAlertAction) in
            self.textField2.text = "test"
        }))

        alertController.addAction(UIAlertAction(title: "demo@example.com",
                                                style: .default,
                                                handler: { (_: UIAlertAction) in
            self.textField2.text = "demo"
        }))

        alertController.popoverPresentationController?.sourceView = textField2
        self.present(alertController, animated: true, completion: nil)
    }
}

extension ViewController {

    @IBAction private func textField1PreviousAction() {
        self.view.endEditing(true)
    }

    @IBAction private func textView1PreviousAction() {
        textField1.becomeFirstResponder()
    }

    @IBAction private func textField2PreviousAction() {
        textView1.becomeFirstResponder()
    }

    @IBAction private func textView2PreviousAction() {
        textField2.becomeFirstResponder()
    }
}

extension ViewController {

    @IBAction private func textField1NextAction() {
        textView1.becomeFirstResponder()
    }

    @IBAction private func textView1NextAction() {
        textField2.becomeFirstResponder()
    }

    @IBAction private func textField2NextAction() {
        textView2.becomeFirstResponder()
    }

    @IBAction private func textView2NextAction() {
        self.view.endEditing(true)
    }
}

extension ViewController {

}
