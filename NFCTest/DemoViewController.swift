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
    
    var tagReader: TagReader?
    var apduHelper: APDUHelper = APDUHelper()
    var tagSession: NFCTagReaderSession?
    
    @IBOutlet weak var contentText: UITextField!
    @IBOutlet weak var pwdText: UITextField!
    @IBOutlet weak var outputLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
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

}

// MARK: - IBAction
extension DemoViewController {
    @IBAction func restoreTagReaderAction(_ sender: Any) {
        outputLabel.text = "restore start!"
        guard let pwd = pwdText.text,pwd.count > 0 else {
            showAlertMessage("restore","pinCode empty")
            outputLabel.text = "restore pinCode empty!"
            return
        }
        tagReader = TagReader(.restore,pwd,"")
        readTag()
    }
    
    @IBAction func resetTagReaderAction(_ sender: Any) {
        outputLabel.text = "reset start!"
        tagReader = TagReader(.reset,"","")
        readTag()
    }
    
    @IBAction func backupTagReaderAction(_ sender: Any) {
        outputLabel.text = "backup start!"
        guard let pwd = pwdText.text,pwd.count > 0 else {
            showAlertMessage("backup","pinCode empty")
            outputLabel.text = "backup pinCode empty!"
            return
        }
        guard let content = contentText.text,content.count > 0 else {
            showAlertMessage("backup","content empty")
            outputLabel.text = "backup content empty!"
            return
        }
        tagReader = TagReader(.backup,pwd,content)
        readTag()
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
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
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
                if let tagReader = self.tagReader {
                    self.apduHelper.setupSecureChannel(tag, tagReader: tagReader)
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


