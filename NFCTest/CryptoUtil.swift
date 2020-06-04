//
//  CryptoUtil.swift
//  NFCTest
//
//  Created by Quincy Chang on 2020/6/1.
//  Copyright © 2020 Ed. All rights reserved.
//

import UIKit
import CryptoSwift

public class CryptoUtil {
    
    let aes: AES?
    
    public init(key: Data) {
        do {
            let iv: Array<UInt8> = [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]
            aes = try AES(key: key.map { $0 }, blockMode: CBC(iv: iv), padding: .pkcs5)
        } catch {
            print(error)
            aes = nil
        }
    }
    public func encryptAES(data: Data) -> Data {
        do {
            let ciphertext = try self.aes!.encrypt(data.map { $0 })
            return Data(ciphertext)
        } catch {
            print(error)
            return Data()
        }
    }

    public func decryptAES(data: Data) -> Data {
        do {
            let ciphertext = try self.aes!.decrypt(data.map { $0 })
            return Data(ciphertext)
        } catch {
            print(error)
            return Data()
        }
    }
}
