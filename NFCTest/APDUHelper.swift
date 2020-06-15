//
//  APDUHelper.swift
//  NFCTest
//
//  Created by Ed on 2019/11/19.
//  Copyright © 2019 Ed. All rights reserved.
//

import UIKit
import CoreNFC

class APDUHelper: NSObject {
    var completionHelper: returnResponse?
    
    private func restore(_ tag: NFCISO7816Tag, aes: CryptoUtil, tagReader: TagReader) {
        let apduHeader = APDU.RESTORE
        let apduData = KeyUtil.sha256(data: tagReader.password.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
    
    private func reset(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.RESET
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: nil)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
    
    private func backup(_ tag: NFCISO7816Tag, aes: CryptoUtil, tagReader: TagReader) {
        let apduHeader = APDU.BACKUP
        var apduData = KeyUtil.sha256(data: tagReader.password.data(using: .utf8)!)
        apduData.append(tagReader.content.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
    
    private func prepareAPDU(aes: CryptoUtil, apduHeader: Data, apduData: Data?) -> [Data] {
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
    
    private func sendAPDU(_ tag: NFCISO7816Tag, aes: CryptoUtil, apdus: [Data]) {
        var result = Data()
        for i in 0..<apdus.count {
            let apdu = NFCISO7816APDU.init(data: apdus[i])!
            tag.sendCommand(apdu: apdu) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
                if let readerError = error as? NFCReaderError ,readerError.code == .readerTransceiveErrorTagConnectionLost {
                    if let completion = self.completionHelper {
                        completion(.error("tag connection lost!"))
                    }
                    return
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
                
                if let completion = self.completionHelper {
                    completion((sw1String + sw2String == "9000") ? .success("success!") : .error(self.handleStatus(status: sw1String + sw2String)))
                }
            }
        }
    }
    
    private func handleStatus(status: String) -> String {
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
    
    private func handleResponse(_ result: Data) {
        print("result       : \(result.hexEncodedString())")
        print("hash         : \(result[0..<32].hexEncodedString())")
        print("salt         : \(result[32..<36].hexEncodedString())")
        print("data in utf8 : \(result[36..<result.count].dataToStr())")
    }
    
    func setupSecureChannel( _ tag: NFCISO7816Tag, tagReader: TagReader) {
        var secureChannelData = Data()
        secureChannelData.append(APDU.CHANNEL_ESTABLISH)
        secureChannelData.append(GenuineKey.SessionAppPublicKey)
        let apdu = NFCISO7816APDU.init(data: secureChannelData)!
        
        tag.sendCommand(apdu: apdu) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
            if let readerError = error as? NFCReaderError ,readerError.code == .readerTransceiveErrorTagConnectionLost {
                if let completion = self.completionHelper {
                    completion(.error("tag connection lost!"))
                }
                return
            }
            
            let sw1String = String(sw1, radix: 16)
            let sw2String = String(sw2, radix: 16).padding(toLength: 2, withPad: "0", startingAt: 0)
            print("setup secure channel!")
            print("status    : \(sw1String)\(sw2String)")
            print("response  : \(response.hexEncodedString())")
            
            guard response.count > 2 else {
                if let completion = self.completionHelper {
                    completion(.error("secure channel invalid."))
                }
                return
            }
            
            if sw1String + sw2String != "9000" {
                if let completion = self.completionHelper {
                    completion(.error(self.handleStatus(status: sw1String + sw2String)))
                }
                return
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
            
            switch tagReader.action {
            case .reset:
                self.reset(tag, aes: aes)
            case .restore:
                self.restore(tag, aes: aes, tagReader: tagReader)
            case .backup:
                self.backup(tag, aes: aes, tagReader: tagReader)
            }
        }
    }
    
}
