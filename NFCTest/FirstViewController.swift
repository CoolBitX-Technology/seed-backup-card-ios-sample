//
//  FirstViewController.swift
//  NFCTest
//
//  Created by Ed on 2019/11/19.
//  Copyright © 2019 Ed. All rights reserved.
//

import UIKit
import CoreNFC

class FirstViewController: UIViewController, NFCNDEFReaderSessionDelegate, NFCTagReaderSessionDelegate {
    
    var detectedMessages = [NFCNDEFMessage]()
    var ndefSession: NFCNDEFReaderSession?
    var tagSession: NFCTagReaderSession?
    
    //CWS卡片的Tag可能是MIFARE DESFire，依循ISO/IEC 14443
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func NDEFReaderAction(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        ndefSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        ndefSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        ndefSession?.begin()

    }

    //-----------------NDEF Reader delegate----------------
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("didInvalidateWithError:\(error)")
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("readerSessionDidBecomeActive:\(session.description)")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("didDetect_tags:\(tags)")
        session.connect(to: tags.first!) { (error: Error?) in
            if error != nil {
                print("connect_error:\(String(describing: error))")
            }
            tags.first?.queryNDEFStatus(completionHandler: { (status: NFCNDEFStatus, intValue: Int, error: Error?) in
                if error != nil {
                    session.invalidate(errorMessage: "Fail to determine NDEF status.  Please try again.")
                    return
                }
                
                if status == .notSupported {
                    session.invalidate(errorMessage: "Tag not notSupported.")
                    return
                } else if status == .readOnly {
                    session.invalidate(errorMessage: "Tag is not writable.")
                } else if status == .readWrite {
//                    let textPayload = NFCNDEFPayload.wellKnownTypeURIPayload(string: "no hello")
//                    let payloadData = "no hello".data(using: .utf8)!
//                    let textPayload = NFCNDEFPayload.init(format: NFCTypeNameFormat.nfcWellKnown, type: "T".data(using: .utf8)!, identifier: Data.init(count: 0), payload: payloadData, chunkSize: 0)
//                    let myMessage = NFCNDEFMessage(records: [textPayload])
//                    let tag:NFCNDEFTag = tags.first!
//                    print("write_myMessage:\(myMessage)")
//                    tag.writeNDEF(myMessage) { (error: Error?) in
//                        if error != nil {
//                            print("write_error:\(String(describing: error))")
//                            session.invalidate(errorMessage: "Update tag failed. Please try again.")
//                        } else {
//                            session.alertMessage = "Update success!"
//                            // 6
//                            session.invalidate()
//                        }
//                    }
                    
                    tags.first?.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                        if error != nil || message == nil {
                            session.invalidate(errorMessage: "Read error. Please try again.")
                            return
                        }
                        let payload:NFCNDEFPayload = (message?.records.first)!;
                        print("NDEF_payload_type:\(self.dataToStr(data: payload.type)) ID:\(self.dataToStr(data: payload.identifier)) payload:\(self.dataToStr(data: payload.payload))")
                        session.alertMessage = self.dataToStr(data: payload.payload)
                        session.invalidate()
                    })
                }
            })
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("didDetectNDEFs_message:\(messages)")
    }
    
    
    @IBAction func TagReaderAction(_ sender: Any) {

        tagSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
    }
    
//------------------Tag Reader delegate------------------
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("tagReader_SessionDidBecomeActive:\(session.description)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("tagReader_didInvalidateWithError:\(error)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("tagReader_didDetect_tags:\(tags)")
        
//        var ndefTag: NFCNDEFTag
        var ndefTag: NFCMiFareTag
        
        switch tags.first! {
//        case let .iso7816(tag):
//            ndefTag = tag
//        case let .feliCa(tag):
//            ndefTag = tag
//        case let .iso15693(tag):
//            ndefTag = tag
        case let .miFare(tag):
            ndefTag = tag
        @unknown default:
            session.invalidate(errorMessage: "Tag not valid.")
            return
        }
        
        print("tag_description:\(ndefTag.description)")
        print("MiFare_family:\(ndefTag.mifareFamily.rawValue)") //4:desfire
        session.connect(to: tags.first!) { (error: Error?) in
            if error != nil {
                print("tagReader_connectErr:\(String(describing: error))")
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            let message = "no hello"
            let payloadData = message.data(using: .utf8)!
            let textPayload = NFCNDEFPayload.init(format: NFCTypeNameFormat.nfcWellKnown, type: "T".data(using: .utf8)!, identifier: Data.init(count: 0), payload: payloadData, chunkSize: 0)
            let ndefMessage = NFCNDEFMessage(records: [textPayload])
            ndefTag.writeNDEF(ndefMessage) { (error: Error?) in
                if error != nil {
                    print("write_error:\(String(describing: error))")
                    session.invalidate(errorMessage: "Update tag failed. Please try again.")
                } else {
                    session.alertMessage = "Update success!\nmessage:\(message)"
                    session.invalidate()
                }
            }
            
//            let cm00A4 = NFCISO7816APDU(instructionClass:0x00, instructionCode:0xA4, p1Parameter:0x04, p2Parameter:0x00, data: self.dataWithHexString(hex: "C1C2C3C4C5"), expectedResponseLength:16)
//            ndefTag.sendMiFareISO7816Command(cm00A4) { (data, int1, int2, error) in
//                print("sendMiFareResult_00A4:\(data) int1:\(int1) int2:\(int2) error:\(String(describing: error))");
//                    let cm8052 = NFCISO7816APDU(instructionClass:0x80, instructionCode:0x52, p1Parameter:0x00, p2Parameter:0x00, data: Data(), expectedResponseLength:16)
//                    ndefTag.sendMiFareISO7816Command(cm8052) { (data, int1, int2, error) in
//                        print("sendMiFareResult_8052:\([UInt8](data)) int1:\(int1) int2:\(int2) error:\(String(describing: error))");
//                    }
//            }
            
//            ndefTag.sendMiFareCommand(commandPacket: Data()) { (data, error) in
//                print("sendMiFareResult_data:\(data) error:\(String(describing: error))");
//                //NFCError Code=100 "Tag connection lost"
//            }
            
//            ndefTag.queryNDEFStatus() { (status: NFCNDEFStatus, _, error: Error?) in
//
//                if status == .notSupported {
//                    session.invalidate(errorMessage: "Tag not valid.")
//                    return
//                }
//
//                ndefTag.readNDEF() { (message: NFCNDEFMessage?, error: Error?) in
//                    if error != nil || message == nil {
//                        session.invalidate(errorMessage: "Read error. Please try again.")
//                        return
//                    }
//                    let payload:NFCNDEFPayload = (message?.records.first)!;
//                    print("TAGNDEF_payload_type:\(self.dataToStr(data: payload.type)) ID:\(self.dataToStr(data: payload.identifier)) payload:\(self.dataToStr(data: payload.payload))")
//
//                }
//            }
        }
    }
    
    func dataToStr(data:Data) -> String {
        return String(data:data, encoding: String.Encoding.utf8) ?? ""
    }
    
    func dataWithHexString(hex: String) -> Data {
        var hex = hex
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

