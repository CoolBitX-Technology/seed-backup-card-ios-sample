//
//  FirstViewController.swift
//  NFCTest
//
//  Created by Ed on 2019/11/19.
//  Copyright © 2019 Ed. All rights reserved.
//

import UIKit
import CoreNFC

class FirstViewController: UIViewController {
    
    var tagSession: NFCTagReaderSession?
    //CWS卡片的Tag可能是MIFARE DESFire，依循ISO/IEC 14443
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func TagReaderAction(_ sender: Any) {
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
    }
    
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
                self.send80360000(session, didDetect: tag)
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
    
    func send80360000(_ session: NFCTagReaderSession, didDetect tag: NFCISO7816Tag) {
        let myAPDU = NFCISO7816APDU(instructionClass:0x80, instructionCode:0x36, p1Parameter:0, p2Parameter:0, data: self.sendData(), expectedResponseLength:16)
        tag.sendCommand(apdu: myAPDU) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
            guard error != nil && !(sw1 == 0x90 && sw2 == 0) else {
                session.invalidate(errorMessage: "INS codes= 36, response: No further qualification:\(String(sw1, radix: 16))\(String(sw2, radix: 16))")
                if let err = error {
                    print("error:\(err.localizedDescription)")
                }
                return
            }
            print("sendCommand:\(String(sw1, radix: 16))\(String(sw2, radix: 16))")//6298
        }
            
    }
    
    func send00B00000(_ session: NFCTagReaderSession, didDetect tag: NFCISO7816Tag) {
        let myAPDU = NFCISO7816APDU(instructionClass:0x00, instructionCode:0xB0, p1Parameter:0, p2Parameter:0, data: self.sendData(), expectedResponseLength:16)
        tag.sendCommand(apdu: myAPDU) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
            guard error != nil && !(sw1 == 0x90 && sw2 == 0) else {
                session.invalidate(errorMessage: "INS codes= B0, response: No further qualification:\(String(sw1, radix: 16))\(String(sw2, radix: 16))")
                if let err = error {
                    print("error:\(err.localizedDescription)")
                }
                
                return
            }
            print("sendCommand:\(String(sw1, radix: 16))\(String(sw2, radix: 16))")//6e0
        }
            
    }
    
    func sendData() -> Data {
        let st = "80CE00004104cd1adb3954f84835e1b6fbae998108c6662e1b1de367ef77732c47999cf10c20d744facc8924c260330a4f5cb3e069e40ee59a138221a1db7df0959d3d7d495e"
        return st.hex!
    }
    
    func sendISO7816Command(_ session: NFCTagReaderSession, didDetect tag: NFCISO7816Tag) {
        let cm00A4 = NFCISO7816APDU(instructionClass:0x00, instructionCode:0xA4, p1Parameter:0x04, p2Parameter:0x00, data: "C1C2C3C4C5C6".dataWithHexString(), expectedResponseLength:16)
        tag.sendCommand(apdu: cm00A4) { (data, int1, int2, error) in
            guard error != nil && !(int1 == 0x90 && int2 == 0) else {
                session.invalidate(errorMessage: "INS codes= A4, response: No further qualification")
                return
            }
            print("sendISO7816Result_00A4:\(data) int1:\(int1) int2:\(int2) error:\(String(describing: error))");
            let cm8052 = NFCISO7816APDU(instructionClass:0x80, instructionCode:0x52, p1Parameter:0x00, p2Parameter:0x00, data: Data(), expectedResponseLength:16)
            tag.sendCommand(apdu: cm8052) { (data, int1, int2, error) in
                guard error != nil && !(int1 == 0x90 && int2 == 0) else {
                    session.invalidate(errorMessage: "INS codes= 52, response: No further qualification")
                    return
                }
                print("sendISO7816Result_8052:\([UInt8](data)) int1:\(int1) int2:\(int2) error:\(String(describing: error))");
            }
        }
    }
    
}

