//
//  Extension.swift
//  NFCTest
//
//  Created by JemmaLiu on 2020/4/13.
//  Copyright © 2020 Ed. All rights reserved.
//

import UIKit

extension String {
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
    func dataToStr() -> String {
        return String(data:self, encoding: String.Encoding.utf8) ?? ""
    }
}

