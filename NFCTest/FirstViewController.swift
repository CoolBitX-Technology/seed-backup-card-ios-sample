//
//  FirstViewController.swift
//  NFCTest
//
//  Created by Ed on 2019/11/19.
//  Copyright © 2019 Ed. All rights reserved.
//

import UIKit
import CoreNFC

enum TagReaderAction {
    case backup
    case restore
    case reset
}


class FirstViewController: UIViewController {
    var action: TagReaderAction?
    var tagSession: NFCTagReaderSession?
    //CWS卡片的Tag可能是MIFARE DESFire，依循ISO/IEC 14443
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
    
    func exe() {
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
        let SECURE_CHANNEL_APDU = NFCISO7816APDU.init(data: (APDU.SECURE_CHANNEL + GenuineKey.SessionAppPublicKey).dataWithHexString())!
        tag.sendCommand(apdu: SECURE_CHANNEL_APDU) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
            let responseHexString = response.byteArrayToHexString()
            print("sw1=\(sw1)/\(String(sw1, radix: 16)),sw2=\(sw2)/\(String(sw2, radix: 16))")
            print("response=\(responseHexString)")
            /*guard error != nil && !(sw1 == 0x90 && sw2 == 0) else {
                return
            }*/
            guard responseHexString.count > 4 else {
                //error
                return
            }
            
            /* READ BINARY
             這個指令收到的回傳格式是：
             [installType(2B)] [cardNameLength(2B)] [cardName (length=cardNameLength,ASCII)] [nonce (32B)] [testCipher(variable length)] 9000
             */
            var tmp:String = responseHexString
            let splitlen = 4
            let installType = String(tmp.prefix(splitlen))
            tmp = String(tmp.suffix(tmp.count-splitlen))
            let cardNameLength = Int(tmp.prefix(splitlen))
            tmp = String(tmp.suffix(tmp.count-splitlen))
            let cardNameHex = String(tmp.prefix(splitlen*2))
            tmp = String(tmp.suffix(tmp.count-splitlen*2))
            let nonceIndex = String(tmp.prefix(64))
            var GenuineMasterPublicKey = ""
            var GenuineMasterChainCode = ""
            switch (installType) {
                case "0000":
                    GenuineMasterPublicKey = GenuineKey.GenuineMasterPublicKey_NonInstalled;
                    GenuineMasterChainCode = GenuineKey.GenuineMasterChainCode_NonInstalled;
                    break
                case "0001":
                    GenuineMasterPublicKey = GenuineKey.GenuineMasterPublicKey_Test;
                    GenuineMasterChainCode = GenuineKey.GenuineMasterChainCode_Test;
                    break
                // add case "0002" here for real HSM key.
                default:
                    break
            }
            
            let GenuineChild1PublicKey = KeyUtil.getChildPublicKey(GenuineMasterPublicKey, GenuineMasterChainCode, cardNameHex);
            let GenuineChild1ChainCode = KeyUtil.getChildChainCode(GenuineMasterPublicKey, GenuineMasterChainCode, cardNameHex);
            let GenuineChild2PublicKey = KeyUtil.getChildPublicKey(GenuineChild1PublicKey, GenuineChild1ChainCode, nonceIndex);
            self.exe()
            
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
