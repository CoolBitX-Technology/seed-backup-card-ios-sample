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

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    func readTag() {
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
    }
    
    @IBAction func restoreTagReaderAction(_ sender: Any) {
        print("")
        print("restore start")
        action = .restore
        readTag()
    }
    
    @IBAction func resetTagReaderAction(_ sender: Any) {
        print("")
        print("reset start")
        action = .reset
        readTag()
    }
    
    @IBAction func backupTagReaderAction(_ sender: Any) {
        print("")
        print("backup start")
        action = .backup
        readTag()
    }
    
    func exe(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        switch self.action {
        case .reset:
            self.reset(tag, aes: aes)
        case .restore:
            self.restore(tag, aes: aes)
        case .backup:
            self.backup(tag, aes: aes)
        case .none:
            break
        }
    }
    
    let testPassword = "testPassword"
    let testContent = "testContent"
    
    func restore(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.RESTORE
        let apduData = KeyUtil.sha256(data: testPassword.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
    
    func reset(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.RESET
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: nil)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
    
    func backup(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.BACKUP
        var apduData = KeyUtil.sha256(data: testPassword.data(using: .utf8)!)
        apduData.append(testContent.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
    
    func prepareAPDU(aes: CryptoUtil, apduHeader: Data, apduData: Data?) -> [Data] {
        var apduCommands = [Data]()
        
        var bytes = [UInt8](repeating: 0, count: 4)
        let _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let salt = Data(bytes)
        
        var hashedData = Data()
        hashedData.append(apduHeader)
        hashedData.append(salt)
        if let apduData = apduData { hashedData.append(apduData) }
        print("raw apdu      :", hashedData.hexEncodedString())
        hashedData = KeyUtil.sha256(data: hashedData)
        print("hashed apdu   :", hashedData.hexEncodedString())
        
        var encodedData = Data()
        encodedData.append(apduHeader)
        encodedData.append(hashedData)
        encodedData.append(salt)
        if let apduData = apduData { encodedData.append(apduData) }
        print("encodedData   :", encodedData.hexEncodedString())
        var cipherData = Data(hex: "00")
        cipherData.append(aes.encryptAES(data: encodedData))
        print("cipherData    :", cipherData.hexEncodedString(), cipherData.count)
        
        let blockSize = 240
        let blockNumber = (cipherData.count - 1) / blockSize + 1
        print("blockNumber   :", blockNumber)
        
        for i in 0..<blockNumber {
            var apduCommand = Data()
            apduCommand.append(Data(hex: "80CC"))
            apduCommand.append(Data(from: UInt8(i)))
            apduCommand.append(Data(from: UInt8(blockNumber)))
            
            let max = i+1 == blockNumber ? cipherData.count : (i+1)*blockNumber
            let data = cipherData[i*blockNumber..<max]
            apduCommand.append(Data(from: UInt8(data.count)))
            apduCommand.append(data)
            
            print("apduCommand   :", apduCommand.hexEncodedString())
            
            apduCommands.append(apduCommand)
        }
        
        return apduCommands
    }

    func sendAPDU(_ tag: NFCISO7816Tag, aes: CryptoUtil, apdus: [Data]) {
        var result = Data()
        for i in 0..<apdus.count {
            let apdu = NFCISO7816APDU.init(data: apdus[i])!
            tag.sendCommand(apdu: apdu) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
                if let readerError = error as? NFCReaderError ,readerError.code == .readerTransceiveErrorTagConnectionLost {
                    self.tagSession?.invalidate(errorMessage: "send command fail!")
                }
                
                let sw1String = String(sw1, radix: 16)
                let sw2String = String(sw2, radix: 16).padding(toLength: 2, withPad: "0", startingAt: 0)
                print("send APDU")
                print("status    : \(sw1String)\(sw2String)")
                print("response  : \(response.hexEncodedString())")
                result.append(response)
                if i == apdus.count - 1 && !result.isEmpty {
                    self.handleResponse(aes.decryptAES(data: result))
                }
                if sw1String + sw2String == "9000" {
                    self.tagSession?.alertMessage = "setup APDU success!"
                } else {
                    self.tagSession?.invalidate(errorMessage: self.handleStatus(status: sw1String + sw2String))
                }
            }
        }
    }
    
    func handleStatus(status: String) -> String {
        var message = String()
        switch status {
        case ErrorCode.SUCCESS:
            message = "success"
            break
        case ErrorCode.RESET_FIRST:
            message = "please reset first"
            break
            
        case ErrorCode.NO_DATA:
            message = "no data"
            break
        case ErrorCode.PING_CODE_NOT_MATCH:
            message = "ping code not match"
            break
        case ErrorCode.CARD_IS_LOCKED:
            message = "card is locked"
            break
        default:
            break
        }
        return message
    }
    
    func handleResponse(_ result: Data) {
        print("result       : \(result.hexEncodedString())")
        print("hash         : \(result[0..<32].hexEncodedString())")
        print("salt         : \(result[32..<36].hexEncodedString())")
        print("data in utf8 : \(result[36..<result.count].dataToStr())")
    }
}

// MARK: - Tag Reader delegate
extension FirstViewController: NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Tag reader active")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("didInvalidateWithError")
        showalertMessage(session, didInvalidateWithError: error)
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
                self.setupSecureChannel(tag)
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
    
    func setupSecureChannel( _ tag: NFCISO7816Tag) {
        
        var secureChannelData = Data()
        secureChannelData.append(APDU.CHANNEL_ESTABLISH)
        secureChannelData.append(GenuineKey.SessionAppPublicKey)
        let apdu = NFCISO7816APDU.init(data: secureChannelData)!
        
        tag.sendCommand(apdu: apdu) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
            if let readerError = error as? NFCReaderError ,readerError.code == .readerTransceiveErrorTagConnectionLost {
                self.tagSession?.invalidate(errorMessage: "send command fail!")
            }
            
            let sw1String = String(sw1, radix: 16)
            let sw2String = String(sw2, radix: 16).padding(toLength: 2, withPad: "0", startingAt: 0)
            print("setup SecureChannel!")
            print("status    : \(sw1String)\(sw2String)")
            print("response  : \(response.hexEncodedString())")
        
            guard response.count > 2 else {
                self.tagSession?.invalidate(errorMessage: "Secure Channel invalid.")
                return
            }
            
            if sw1String + sw2String != "9000" {
                self.tagSession?.invalidate(errorMessage: self.handleStatus(status: sw1String + sw2String))
            }
            /* READ BINARY
             這個指令收到的回傳格式是：
             [installType(2B)] [cardNameLength(2B)] [cardName (length=cardNameLength,ASCII)] [nonce (32B)] [testCipher(variable length)] 9000
             */
            let installType = response[0..<2].hexEncodedString()
            print("installType    :", installType)
            
            let cardNameLength = response[2..<4].hexEncodedString()
            print("cardNameLength :", cardNameLength)
            let offset = 4 + Int(cardNameLength, radix: 16)!
            
            let cardName = response[4..<offset]
            print("cardName       :", cardName.hexEncodedString())
            
            let nonce = response[offset..<offset+32]
            print("nonce          :", nonce.hexEncodedString())
            
            let testCipher = response[offset+32..<response.count]
            print("testCipher     :", testCipher.hexEncodedString())
            print("")
            
            var publicKey = Data()
            var chainCode = Data()
            switch (installType) {
                case "0000":
                    publicKey = GenuineKey.GenuineMasterPublicKey_NonInstalled;
                    chainCode = GenuineKey.GenuineMasterChainCode_NonInstalled;
                    break
                case "0001":
                    publicKey = GenuineKey.GenuineMasterPublicKey_Test;
                    chainCode = GenuineKey.GenuineMasterChainCode_Test;
                    break
                // add case "0002" here for real HSM key.
                default:
                    break
            }
            
            publicKey = KeyUtil.compressPublicKey(publicKey: publicKey)
            print("pubkey  :", publicKey.hexEncodedString())
            print("chain   :", chainCode.hexEncodedString())

            (publicKey, chainCode) = KeyUtil.derived(publicKey: publicKey, chainCode: chainCode, indexData: cardName)
            publicKey = KeyUtil.compressPublicKey(publicKey: publicKey)
            print("pubkey  :", publicKey.hexEncodedString())
            print("chain   :", chainCode.hexEncodedString())
            print("")
            
            (publicKey, chainCode) = KeyUtil.derived(publicKey: publicKey, chainCode: chainCode, indexData: nonce)
            print("pubkey  :", publicKey.hexEncodedString())
            print("chain   :", chainCode.hexEncodedString())
            print("")
            
            var ecdhKey = KeyUtil.ecdh(privateKey: GenuineKey.SessionAppPrivateKey, publicKey: publicKey)
            ecdhKey = ecdhKey[1..<ecdhKey.count]
            print("ecdhKey :", ecdhKey.hexEncodedString())
            
            let aes = CryptoUtil.init(key: ecdhKey)
            let result = aes.decryptAES(data: testCipher)
            print("result  :", result.hexEncodedString())
            
            self.exe(tag, aes: aes)
        }
    }
}

// MARK: - showalertMessage
extension FirstViewController {
    func showalertMessage(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError, (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
        && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
            DispatchQueue.main.async {
                // Show alert dialog box when the invalidation reason is not because of a read success from the single tag read mode,
                // or user cancelled a multi-tag read mode session from the UI or programmatically using the invalidate method call.
                print("error code: \(readerError.code.rawValue),\(error.localizedDescription)")
                let alertController = UIAlertController(title: "Session Invalidated", message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
