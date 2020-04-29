//
//  Extension.swift
//  NFCTest
//
//  Created by JemmaLiu on 2020/4/13.
//  Copyright © 2020 Ed. All rights reserved.
//

import UIKit

public enum APDU {
    static let BACKUP = "80320500"
    static let RESTORE = "80340000"
    static let RESET = "80360000"
    static let SECURE_CHANNEL = "80CE000041" // apduHeader + salt(4B)長度 41是16進位 SHA256後結果
}

public enum GenuineKey {
    static let SessionAppPublicKey =  "04e834395299dc3757d15bbea29aaa44fd421e3252012cba9d71fabc13d386133425a24ea0c181d70e1723cca7764c5a4e6bd326d5a9aac799f22acbf501bd7181";  //need random
    static let GenuineMasterChainCode_NonInstalled = "611c6956ca324d8656b50c39a0e5ef968ecd8997e22c28c11d56fb7d28313fa3";
    static let GenuineMasterPublicKey_NonInstalled = "04e720c727290f3cde711a82bba2f102322ab88029b0ff5be5171ad2d0a1a26efcd3502aa473cea30db7bc237021d00fd8929123246a993dc9e76ca7ef7f456ade";
    static let GenuineMasterChainCode_Test = "f5a0c5d9ffaee0230a98a1cc982117759c149a0c8af48635776135dae8f63ba4";
    static let GenuineMasterPublicKey_Test = "0401e3a7de779276ef24b9d5617ba86ba46dc5a010be0ce7aaf65876402f6a53a5cf1fecab85703df92e9c43e12a49f33370761153216df8291b7aa2f1a775b086";
}

public class KeyUtil {
    public static func getChildPublicKey(_ parentPublicKey: String,_ chainCode: String,_ index: String) -> String {
        // todo
        return ""
    }
    
    public static func getChildChainCode(_ parentPublicKey: String,_ chainCode: String,_ index: String) -> String {
        // todo
        return ""
    }
}

extension String {
    // Ed
    func dataWithHexString() -> Data {
        var hex = self
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
    
    // tom
    func seDataWithHexString() -> Data { 
        var hex = self
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        print(data.byteArrayToHexString())
        return data
    }
    
    // https://stackoverflow.com/questions/26501276/converting-hex-string-to-nsdata-in-swift
    var hex: Data? {
      var value = self
      var data = Data()

      while value.count > 0 {
        let subIndex = value.index(value.startIndex, offsetBy: 2)
        let c = String(value[..<subIndex])
        value = String(value[subIndex...])

        var char: UInt8
        if #available(iOS 13.0, *) {
          guard let int = Scanner(string: c).scanInt32(representation: .hexadecimal) else { return nil }
          char = UInt8(int)
        } else {
          var int: UInt32 = 0
          Scanner(string: c).scanHexInt32(&int)
          char = UInt8(int)
        }

        data.append(&char, count: 1)
      }

      return data
    }
}

extension Data {
    // Tom
    func byteArrayToHexString() -> String {
        let HexLookup : [Character] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" ]
        var stringToReturn = ""
        for oneByte in self {
            let asInt = Int(oneByte)
            stringToReturn.append(HexLookup[asInt >> 4])
            stringToReturn.append(HexLookup[asInt & 0x0f])
        }
        return stringToReturn
    }
    
    // Ed
    func dataToStr() -> String {
        return String(data:self, encoding: String.Encoding.utf8) ?? ""
    }
}

