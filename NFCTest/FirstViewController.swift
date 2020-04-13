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
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
    }
}

// MARK: - Tag Reader delegate
extension FirstViewController: NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("tagReader_SessionDidBecomeActive:\(session.description)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("tagReader_didInvalidateWithError:\(error)")
    }
    
    func isNFCNDEFTag(didDetect tags: [NFCTag]) -> Bool {
        var ndefTag: NFCNDEFTag
        var isNFCNDEFTag = false
        switch tags.first! {
        case let .iso7816(tag):
            ndefTag = tag
            isNFCNDEFTag = true
        case let .feliCa(tag):
            ndefTag = tag
            isNFCNDEFTag = true
        case let .iso15693(tag):
            ndefTag = tag
            isNFCNDEFTag = true
        case let .miFare(tag):
            ndefTag = tag
        @unknown default: break //Tag not valid.
        }
        return isNFCNDEFTag
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("tagReader_didDetect_tags:\(tags)")
        
        var ndefTag: NFCMiFareTag
    
        switch tags.first! {
        case let .miFare(tag):
            ndefTag = tag
        case .feliCa(_), .iso7816(_), .iso15693(_):
            session.invalidate(errorMessage: "Tag not MiFare.")
            return
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
            
            //self.mark(MiFareTag: ndefTag, TagReaderSession: session)
            
        }
    }
    
    func mark(MiFareTag ndefTag: NFCMiFareTag, TagReaderSession session: NFCTagReaderSession) {
        let cm00A4 = NFCISO7816APDU(instructionClass:0x00, instructionCode:0xA4, p1Parameter:0x04, p2Parameter:0x00, data: "C1C2C3C4C5".dataWithHexString(), expectedResponseLength:16)
        ndefTag.sendMiFareISO7816Command(cm00A4) { (data, int1, int2, error) in
            print("sendMiFareResult_00A4:\(data) int1:\(int1) int2:\(int2) error:\(String(describing: error))");
            let cm8052 = NFCISO7816APDU(instructionClass:0x80, instructionCode:0x52, p1Parameter:0x00, p2Parameter:0x00, data: Data(), expectedResponseLength:16)
            ndefTag.sendMiFareISO7816Command(cm8052) { (data, int1, int2, error) in
                print("sendMiFareResult_8052:\([UInt8](data)) int1:\(int1) int2:\(int2) error:\(String(describing: error))");
            }
        }
        
        ndefTag.sendMiFareCommand(commandPacket: Data()) { (data, error) in
            print("sendMiFareResult_data:\(data) error:\(String(describing: error))");
            //NFCError Code=100 "Tag connection lost"
        }
        
        ndefTag.queryNDEFStatus() { (status: NFCNDEFStatus, _, error: Error?) in
            
            if status == .notSupported {
                session.invalidate(errorMessage: "Tag not valid.")
                return
            }
            
            ndefTag.readNDEF() { (message: NFCNDEFMessage?, error: Error?) in
                if error != nil || message == nil {
                    session.invalidate(errorMessage: "Read error. Please try again.")
                    return
                }
                let payload:NFCNDEFPayload = (message?.records.first)!;
                print("TAGNDEF_payload_type:\(payload.type.dataToStr()) ID:\(payload.identifier.dataToStr()) payload:\(payload.payload.dataToStr())")
                
            }
        }
    }
}

