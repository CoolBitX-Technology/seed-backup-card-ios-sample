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
        sendAPDU(tag, apdus: apdus, completion: { status, index, num, data in
            var encryptedData = data
            
            if num == 1 {
                let decryptedData = aes.decryptAES(data: encryptedData)
                let response = decryptedData[36..<decryptedData.count].dataToStr()
               
                print("hash         : \(decryptedData[0..<32].hexEncodedString())")
                print("salt         : \(decryptedData[32..<36].hexEncodedString())")
                print("data in utf8 : \(response)")
               
                if let completion = self.completionHelper {
                    completion((status == "9000") ? .success("restore success: " + response) : .error("restore error: " + self.handleStatus(status: status)))
                }
            } else {
                let apdus = Array.init(repeating: Data(hex:"80C20000"), count: Int(num) - 1)
                print("80C2 apdus : \(apdus)")
                self.sendAPDU(tag, apdus: apdus, completion: { status, index, num, data in
                    encryptedData.append(data)
                    let decryptedData = aes.decryptAES(data: encryptedData)
                    let response = decryptedData[36..<decryptedData.count].dataToStr()
                    
                    print("hash         : \(decryptedData[0..<32].hexEncodedString())")
                    print("salt         : \(decryptedData[32..<36].hexEncodedString())")
                    print("data in utf8 : \(response)")
                    
                    if let completion = self.completionHelper {
                        completion((status == "9000") ? .success("restore success: " + response) : .error("restore error: " + self.handleStatus(status: status)))
                    }
                })
            }
        })
    }
    
    private func reset(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.RESET
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: nil)
        sendAPDU(tag, apdus: apdus, completion: { status, index, num, response in
            if let completion = self.completionHelper {
                completion((status == "9000") ? .success("reset success!") : .error("reset error: " + self.handleStatus(status: status)))
            }
        })
    }
    
    private func backup(_ tag: NFCISO7816Tag, aes: CryptoUtil, tagReader: TagReader) {
        let apduHeader = APDU.BACKUP
        var apduData = KeyUtil.sha256(data: tagReader.password.data(using: .utf8)!)
        apduData.append(tagReader.content.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, apdus: apdus, completion: { status, index, num, response in
            if let completion = self.completionHelper {
                completion((status == "9000") ? .success("backup success!") : .error("backup error: " +  self.handleStatus(status: status)))
            }
        })
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
        var cipherData = Data(hex: "00") // [sign(1B)]
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
            
            let max = i+1 == blockNumber ? cipherData.count : (i+1)*blockSize
            print("max           :", max)
            let data = cipherData[i*blockSize..<max]
            apduCommand.append(Data(from: UInt8(data.count)))
            apduCommand.append(data)
            
            print("apduCommand   :", apduCommand.hexEncodedString())
            
            apduCommands.append(apduCommand)
        }
        
        return apduCommands
    }
    
    private func sendAPDU(_ tag: NFCISO7816Tag, apdus: [Data],completion: @escaping (String, UInt8, UInt8, Data) -> Void) {
        var returnData = Data()
        var partialIndex: UInt8 = 0
        var partialNumber: UInt8 = 0
        for i in 0..<apdus.count {
            print("sendAPDU   :", apdus[i])
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
                let status = sw1String + sw2String
                print("send APDU")
                print("status    : \(status)")
                if !response.isEmpty {
                    var data = response
                    print("response  : \(response.hexEncodedString())")
                    partialIndex = data.popFirst()!
                    print("partialIndex  :", partialIndex)
                    partialNumber = data.popFirst()!
                    print("partialNumber :", partialNumber)
                    returnData.append(data)
                }
                
                if i == apdus.count - 1 {
                    completion(status, partialIndex, partialNumber, returnData)
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
             [installType(2B)] [cardNameLength(2B)] [cardName (length=cardNameLength,ASCII)] [nonce (4B)] [testCipher(variable length)] 9000
             */
            let installType = response[0..<2].hexEncodedString()
            print("installType    :", installType)
            
            let cardNameLength = response[2..<4].hexEncodedString()
            print("cardNameLength :", cardNameLength)
            let offset = 4 + Int(cardNameLength, radix: 16)!
            
            var cardName = response[4..<offset]
            print("cardName       :", cardName.hexEncodedString())
            cardName = KeyUtil.sha256(data: cardName)[0..<4]
            if cardName.bytes[0] > 127 {
                cardName = Data([127]) + cardName[1..<4]
            }
            print("cardNameHash   :", cardName.hexEncodedString())
            
            let nonce = response[offset..<offset+4]
            print("nonce          :", nonce.hexEncodedString())
            
            let testCipher = response[offset+4..<response.count]
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
