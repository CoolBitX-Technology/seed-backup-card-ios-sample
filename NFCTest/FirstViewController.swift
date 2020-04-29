//
//  FirstViewController.swift
//  NFCTest
//
//  Created by Ed on 2019/11/19.
//  Copyright © 2019 Ed. All rights reserved.
//

import UIKit
import CoreNFC

public enum APDU {
    static let BACKUP = "80320500"
    static let RESTORE = "80340000"
    static let RESET = "80360000"
    static let SECURE_CHANNEL = "80CE000041"
}

enum TagReaderAction {
    case backup
    case restore
    case reset
}


class FirstViewController: UIViewController {
    var action: TagReaderAction?
    var tagSession: NFCTagReaderSession?
    //CWS卡片的Tag可能是MIFARE DESFire，依循ISO/IEC 14443
    let sessionAppPrivateKey =  "04e834395299dc3757d15bbea29aaa44fd421e3252012cba9d71fabc13d386133425a24ea0c181d70e1723cca7764c5a4e6bd326d5a9aac799f22acbf501bd7181";  //need random
    let GenuineMasterChainCode_NonInstalled = "611c6956ca324d8656b50c39a0e5ef968ecd8997e22c28c11d56fb7d28313fa3";
    let GenuineMasterPublicKey_NonInstalled = "04e720c727290f3cde711a82bba2f102322ab88029b0ff5be5171ad2d0a1a26efcd3502aa473cea30db7bc237021d00fd8929123246a993dc9e76ca7ef7f456ade";
    let GenuineMasterChainCode_Test = "f5a0c5d9ffaee0230a98a1cc982117759c149a0c8af48635776135dae8f63ba4";
    let GenuineMasterPublicKey_Test = "0401e3a7de779276ef24b9d5617ba86ba46dc5a010be0ce7aaf65876402f6a53a5cf1fecab85703df92e9c43e12a49f33370761153216df8291b7aa2f1a775b086";
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    func TagReader() {
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
    }
    
    @IBAction func restoreTagReaderAction(_ sender: Any) {
        action = .restore
        TagReader()
    }
    
    @IBAction func resetTagReaderAction(_ sender: Any) {
        action = .reset
        TagReader()
    }
    
    @IBAction func backupTagReaderAction(_ sender: Any) {
        action = .backup
        TagReader()
    }
    
    func restore() {
        
    }
    
    func reset() {
        
    }
    
    func backup() {
        
    }
}

// MARK: - Tag Reader delegate
extension FirstViewController: NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Tag reader active")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        //showalertMessage(session, didInvalidateWithError: error)
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("Detect tag!")
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        if case let .iso7816(tag) = tags.first! {
            session.connect(to: tags.first!) { (error: Error?) in
                if error != nil {
                    print("connect tag error:\(String(describing: error))")
                    session.invalidate(errorMessage: "Connection iso7816 error. Please try again.")
                    return
                }
                print("connecting to Tag iso7816!")
                self.sendCmd(session, didDetect: tag)
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
  
    func sendCmd(_ session: NFCTagReaderSession, didDetect tag: NFCISO7816Tag) {
        let SECURE_CHANNEL_APDU = NFCISO7816APDU.init(data: (APDU.SECURE_CHANNEL + self.sessionAppPrivateKey).dataWithHexString())!
        tag.sendCommand(apdu: SECURE_CHANNEL_APDU) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
            let responseStr = response.byteArrayToHexString()
            print("sw1=\(sw1)", "sw2=\(sw2)")
            print("response=\(responseStr)")
            guard responseStr.count > 4 else {
                //error
                return
            }
            
            // READ BINARY
            switch self.action {
            case .reset:
                self.reset()
            case .restore:
                self.restore()
            case .backup:
                self.backup()
            case .none:
                break
            }
        }
    }
    
}

// MARK: - useless
extension FirstViewController {
    func showalertMessage(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            // Show alert dialog box when the invalidation reason is not because of a read success from the single tag read mode,
            // or user cancelled a multi-tag read mode session from the UI or programmatically using the invalidate method call.
            let alertMessage = (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
            && (readerError.code != .readerSessionInvalidationErrorUserCanceled) ? error.localizedDescription : session.alertMessage
            let alertController = UIAlertController(title: "Session Invalidated", message: alertMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            DispatchQueue.main.async {
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
