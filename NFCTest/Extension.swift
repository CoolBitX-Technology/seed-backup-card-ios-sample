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
}
class Extension: NSObject {

}

extension Data {
    func dataToStr() -> String {
        return String(data:self, encoding: String.Encoding.utf8) ?? ""
    }
}

