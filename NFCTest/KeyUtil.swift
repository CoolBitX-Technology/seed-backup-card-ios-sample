//
//  KeyUtil.swift
//  NFCTest
//
//  Created by Quincy Chang on 2020/6/1.
//  Copyright © 2020 Ed. All rights reserved.
//

import UIKit
import secp256k1
import CryptoKit

public enum Feature: String {
    case Info = "info"
    case Backup = "back"
    case Restore = "restore"
    case Reset = "reset"
}

public struct Command {
    var feature: Feature
    var password: String
    var content: String
    init(_ fe: Feature,_ pwd: String,_ backupcontent: String) {
        feature = fe
        password = pwd
        content = backupcontent
    }
}

typealias returnResponse = (Result) -> Void

public enum Result {
    case success(String)
    case error(String)
}

public enum APDU {
    static let BACKUP = Data(hex: "80320500")
    static let RESTORE = Data(hex: "80340000")
    static let RESET = Data(hex: "80360000")
    static let CHANNEL_ESTABLISH = Data(hex: "80CE000041") // apduHeader + 長度41是16進位 + PublicKey
    static let CHANNEL_COMMUNICATE = Data(hex: "80CC")
    // 80CC + [blockIndex(1B,0~blockNumber-1)] [blockNumber(1B,1~255)] [blocklength(1B,0~250)] [block(0~250B)]
}

public enum ErrorCode {
    static let SUCCESS = "9000";
    static let RESET_FIRST = "6330";
    static let NO_DATA = "6370";
    static let PING_CODE_NOT_MATCH = "6350";
    static let CARD_IS_LOCKED = "6390";
}

public enum GenuineKey {
    static let SessionAppPrivateKey = KeyUtil.genPrivateKey()
    static let SessionAppPublicKey = KeyUtil.computePublicKey(fromPrivateKey: SessionAppPrivateKey, compression: false)

    static let GenuineMasterChainCode_NonInstalled = Data(hex: "611c6956ca324d8656b50c39a0e5ef968ecd8997e22c28c11d56fb7d28313fa3")
    static let GenuineMasterPublicKey_NonInstalled = Data(hex: "04e720c727290f3cde711a82bba2f102322ab88029b0ff5be5171ad2d0a1a26efcd3502aa473cea30db7bc237021d00fd8929123246a993dc9e76ca7ef7f456ade")
    static let GenuineMasterChainCode_Test = Data(hex: "f5a0c5d9ffaee0230a98a1cc982117759c149a0c8af48635776135dae8f63ba4")
    static let GenuineMasterPublicKey_Test = Data(hex: "0401e3a7de779276ef24b9d5617ba86ba46dc5a010be0ce7aaf65876402f6a53a5cf1fecab85703df92e9c43e12a49f33370761153216df8291b7aa2f1a775b086")
}

public class KeyUtil {
    public static func genPrivateKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    public static func computePublicKey(fromPrivateKey privateKey: Data, compression: Bool) -> Data {
        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN)) else {
            return Data()
        }
        defer { secp256k1_context_destroy(ctx) }
        var pubkey = secp256k1_pubkey()
        var seckey: [UInt8] = privateKey.map { $0 }
        if seckey.count != 32 {
            return Data()
        }
        if secp256k1_ec_pubkey_create(ctx, &pubkey, &seckey) == 0 {
            return Data()
        }
        if compression {
            var serializedPubkey = [UInt8](repeating: 0, count: 33)
            var outputlen = 33
            if secp256k1_ec_pubkey_serialize(ctx, &serializedPubkey, &outputlen, &pubkey, UInt32(SECP256K1_EC_COMPRESSED)) == 0 {
                return Data()
            }
            if outputlen != 33 {
                return Data()
            }
            return Data(serializedPubkey)
        } else {
            var serializedPubkey = [UInt8](repeating: 0, count: 65)
            var outputlen = 65
            if secp256k1_ec_pubkey_serialize(ctx, &serializedPubkey, &outputlen, &pubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)) == 0 {
                return Data()
            }
            if outputlen != 65 {
                return Data()
            }
            return Data(serializedPubkey)
        }
    }
    
    public static func ecdh(privateKey: Data, publicKey: Data) -> Data {
        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN)) else {
            return Data()
        }
        defer { secp256k1_context_destroy(ctx) }
        
        let publicKeyBytes: [UInt8] = publicKey.map { $0 }
        var pubkey = secp256k1_pubkey()
        if secp256k1_ec_pubkey_parse(ctx, &pubkey, publicKeyBytes, publicKeyBytes.count) == 0 {
            return Data()
        }
        
        if secp256k1_ecdh(ctx, &pubkey, privateKey.map { $0 }) == 0 {
            return Data()
        }
        
        var serializedPubkey = [UInt8](repeating: 0, count: 33)
        var outputlen = 33
        if secp256k1_ec_pubkey_serialize(ctx, &serializedPubkey, &outputlen, &pubkey, UInt32(SECP256K1_EC_COMPRESSED)) == 0 {
            return Data()
        }
        if outputlen != 33 {
            return Data()
        }
        return Data(serializedPubkey)
    }
    
    public static func compressPublicKey(publicKey: Data) -> Data {
        let x = publicKey[1..<33]
        let y = publicKey[33..<65]
        var result = y.bytes[31] % 2 == 0 ? Data(hex: "02") : Data(hex: "03")
        result.append(x)
        return result
    }

    public static func sha256(data: Data) -> Data {
        let hashed = SHA256.hash(data: data)
        return Data(hashed)
    }
    
    public static func hmacsha512(key: Data, data: Data) -> Data {
        var hmac = HMAC<SHA512>.init(key: SymmetricKey.init(data: key))
        hmac.update(data: data)
        let hash = hmac.finalize()
        return Data(hash)
    }

    public static func derived(publicKey: Data, chainCode: Data, indexData: Data) -> (publicKey: Data, chainCode: Data) {
   
        var data = Data()
        data.append(publicKey)

        //var childIndex = CFSwapInt32HostToBig(index) // If the host is big-endian, this function returns arg unchanged.
        //data.append(Data(bytes: &childIndex, count: MemoryLayout<UInt32>.size))
        
        data.append(indexData)
        
        let digest = KeyUtil.hmacsha512(key: chainCode, data: data)
        print("digest  :", digest.hexEncodedString())
        let IL = digest[0..<32]
        let IR = digest[32..<64]
        let retChainCode = IR
        
        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_VERIFY)) else {
            fatalError("Unimplemented")
        }
        defer { secp256k1_context_destroy(ctx) }
        let publicKeyBytes: [UInt8] = publicKey.map { $0 }
        var secpPubkey = secp256k1_pubkey()
        if secp256k1_ec_pubkey_parse(ctx, &secpPubkey, publicKeyBytes, publicKeyBytes.count) == 0 {
            fatalError("Unimplemented")
        }
        if secp256k1_ec_pubkey_tweak_add(ctx, &secpPubkey, IL.map { $0 }) == 0 {
            fatalError("Unimplemented")
        }
        var uncompressedPublicKeyBytes = [UInt8](repeating: 0, count: 65)
        var uncompressedPublicKeyBytesLen = 65
        if secp256k1_ec_pubkey_serialize(ctx, &uncompressedPublicKeyBytes, &uncompressedPublicKeyBytesLen, &secpPubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)) == 0 {
            fatalError("Unimplemented")
        }
        let retPublicKey = Data(uncompressedPublicKeyBytes)
        
        return (retPublicKey, retChainCode)
    }
}
