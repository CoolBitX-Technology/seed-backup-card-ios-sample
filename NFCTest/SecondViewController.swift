//
//  SecondViewController.swift
//  NFCTest
//
//  Created by Ed on 2019/11/19.
//  Copyright © 2019 Ed. All rights reserved.
//

import UIKit
import CoreNFC

class SecondViewController: UIViewController {
    
    var detectedMessages = [NFCNDEFMessage]()
    var ndefSession: NFCNDEFReaderSession?
    
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
    
}

extension SecondViewController: NFCNDEFReaderSessionDelegate {
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("didInvalidateWithError:\(error)")
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("readerSessionDidBecomeActive:\(session.description)")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("didDetectNDEFs_message:\(messages)")
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
                        print("NDEF_payload_type:\(payload.type.dataToStr()) ID:\(payload.identifier.dataToStr()) payload:\(payload.payload.dataToStr())")
                        session.alertMessage = payload.payload.dataToStr()
                        session.invalidate()
                    })
                }
            })
        }
    }
}
