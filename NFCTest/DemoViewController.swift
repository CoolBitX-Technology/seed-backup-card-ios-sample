//
//  DemoViewController.swift
//  NFCTest
//
//  Created by JemmaLiu on 2020/6/10.
//  Copyright © 2020 Ed. All rights reserved.
//

import UIKit
import CoreNFC

class DemoViewController: UIViewController {
    
    var command: Command?
    var apduHelper: APDUHelper = APDUHelper()
    var tagSession: NFCTagReaderSession?
    var selectedFeature: Feature?
    let features = [Feature.Info,Feature.Backup,Feature.Restore,Feature.Reset]
    let picker: UIPickerView = UIPickerView()
    
    @IBOutlet weak var contentText: UITextField!
    @IBOutlet weak var pwdText: UITextField!
    @IBOutlet weak var outputLabel: UILabel!
    @IBOutlet weak var featureText: UITextField!
    @IBOutlet weak var pwdTextView: UIView!
    @IBOutlet weak var contentTextView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        setupMenu()
    }
    
    func setupMenu() {
        featureText.delegate = self
        featureText.tintColor = UIColor.clear
        featureText.rightViewMode = .always
        featureText.rightView = UIImageView(image: UIImage(named: "arrow_down"))
        picker.dataSource = self
        picker.delegate = self
        featureText.inputView = picker
    }
    
    @objc func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func readTag() {
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
    }

    func showAlertMessage(_ alertTitle: String, _ alertMessage: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }

    @IBAction func nfcClicked(_ sender: Any) {
        guard let feature = self.selectedFeature else {
            outputLabel.text = "select feature!"
            return
        }
        
        guard checkpwd() else {
            showAlertMessage(feature.rawValue,"pin empty")
            outputLabel.text = "\(feature.rawValue) pin empty!"
            return
        }
        
        guard checkcontent() else {
            showAlertMessage(feature.rawValue,"content empty")
            outputLabel.text = "\(feature.rawValue) content empty!"
            return
        }
        
        outputLabel.text = "\(feature.rawValue) TagReader!"
        command = Command(feature,pwdText.text!,contentText.text!)
        readTag()
    }
    
    func checkpwd() -> Bool {
        if pwdTextView.isHidden {
            return true
        }
        
        if let pwd = pwdText.text,pwd.count > 0 {
            return true
        }
        return false
    }
    
    func checkcontent() -> Bool {
        if contentTextView.isHidden {
            return true
        }
        
        if let content = contentText.text,content.count > 0 {
            return true
        }
        return false
    }
    
    func selectedFeature(_ feature: Feature) {
        selectedFeature = feature
        featureText.text = feature.rawValue
        pwdTextView.isHidden = feature == .Reset
        contentTextView.isHidden = feature != .Backup
        outputLabel.text = ""
    }

}
// MARK: - UITextFieldDelegate
extension DemoViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false
    }
}
// MARK: - picker dataSource
extension DemoViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return features.count
    }
}

// MARK: - picker delegate
extension DemoViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int)
    -> String? {
        return features[row].rawValue
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedFeature(features[row])
    }
}

// MARK: - Tag Reader delegate
extension DemoViewController: NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Tag reader active")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("Tag reader invalidate")
        // Show alert dialog box when the invalidation reason is not because of a read success from the single tag read mode,
        // or user cancelled a multi-tag read mode session from the UI or programmatically using the invalidate method call.
        if let readerError = error as? NFCReaderError {
            print("error code=\(readerError.code.rawValue),\(error.localizedDescription)")
            if readerError.code == .readerSessionInvalidationErrorUserCanceled {
                DispatchQueue.main.async {
                    self.outputLabel.text = "\(self.selectedFeature!.rawValue) Canceled!"
                }
                return
            }
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead) {
                showAlertMessage("Session Invalidated", error.localizedDescription)
            }
        }
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("Detect tag!")
        if case let .iso7816(tag) = tags.first! {
            session.connect(to: tags.first!) { (error: Error?) in
                if error != nil {
                    print("connect tag error:\(String(describing: error))")
                    session.invalidate(errorMessage: "Connection iso7816 error. Please try again.")
                    return
                }
                print("connecting to Tag iso7816!")
                self.apduHelper.completionHelper = { (result) in
                    switch result {
                    case .success(let message):
                        self.tagSession?.alertMessage = message
                        self.tagSession?.invalidate()
                        DispatchQueue.main.async {
                            self.outputLabel.text = message
                        }
                        break
                    case .error(let error):
                        self.tagSession?.invalidate(errorMessage: error)
                        DispatchQueue.main.async {
                            self.outputLabel.text = error
                        }
                        break
                    }
                }
                if let command = self.command {
                    self.apduHelper.setupSecureChannel(tag, command: command)
                }
            }
            return
        }
        
        if case .miFare(_) = tags.first! {
            session.invalidate(errorMessage: "miFare tag.")
        } else if case .feliCa(_) = tags.first! {
            session.invalidate(errorMessage: "feliCa tag.")
        } else if case .iso15693(_) = tags.first! {
            session.invalidate(errorMessage: "iso15693 tag.")
        } else {
            session.invalidate(errorMessage: "unknown tag.")
        }
    }
}


