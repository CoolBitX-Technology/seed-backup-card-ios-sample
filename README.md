# CoolWalletS SeedBackupCard SampleCode

> SeedBackupCard SampleCode for CoolWalletS

```
version:    1.0.0
status:     release
copyright:  coolbitX
```

## Support Devices
- iPhone 7 / iPhone 7 Plus
- iOS 13

## Requirements
- Add NFC capabilities to your project.
- In Your apps plist file, you need to add: ISO-7816 application identifiers for NFC Tag Reader Session.

  ```
  <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>  
  <array>  
  <string>C1C2C3C5C6</string>  
  </array>  
 
  ```

  C1C2C3C5C6 is the AID of the NFC chip.

- Setting Swift Package in Xcode
  1. Open Xcode > Click Xcode in header > File > Swift Packages > Add Packages Dependency...
  2. Enter https://github.com/CoolBitX-Technology/secp256k1.swift/ package repository

## Example Usage

### 0. APDU Command  & ErrorCode

You can see SecureChannel Commentary in SecureChannel.txt, implement in function setupSecureChannel(_ tag: NFCISO7816Tag), define APDU code in KeyUtil.swift.

```swift 
  public enum APDU {
    static let BACKUP = Data(hex: "80320500")
    static let RESTORE = Data(hex: "80340000")
    static let RESET = Data(hex: "80360000")
    static let CHANNEL_ESTABLISH = Data(hex: "80CE000041") 
    static let CHANNEL_COMMUNICATE = Data(hex: "80CC")
}

public enum ErrorCode {
    static let SUCCESS = "9000";
    static let RESET_FIRST = "6330";
    static let NO_DATA = "6370";
    static let PING_CODE_NOT_MATCH = "6350";
    static let CARD_IS_LOCKED = "6390";
}
```

### 1. Swift Package Dependencies
secp256k1 https://github.com/CoolBitX-Technology/secp256k1.swift/
CryptoSwift https://github.com/krzyzanowskim/CryptoSwift.git


### 2. Initial NFC
1.Create session with a NFCTagReaderSessionDelegate object
```swift
      func readTag() {
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        tagSession?.begin()
        
    }

```
2.Implement optional readerSession(_ session: NFCTagReaderSession, didDetect tags:)
```swift
  if case let .iso7816(tag) = tags.first! {
    session.connect(to: tags.first!) { (error: Error?) in
      if error != nil {
        print("connect tag error:\(String(describing: error))")
        session.invalidate(errorMessage: "Connection iso7816 error. Please try again.")
        return
      }
      print("connecting to Tag iso7816!")
      self.setupSecureChannel(tag)
    }
    return
  }

```
### 3. BackUp Sample Code


```swift
  func backup(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.BACKUP
        var apduData = KeyUtil.sha256(data: testPassword.data(using: .utf8)!)
        apduData.append(testContent.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
```

### 4. Restore Sample Code


```swift
  func restore(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.RESTORE
        let apduData = KeyUtil.sha256(data: testPassword.data(using: .utf8)!)
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: apduData)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
```

### 5. Reset Sample Code


```swift
  func reset(_ tag: NFCISO7816Tag, aes: CryptoUtil) {
        let apduHeader = APDU.RESET
        let apdus = prepareAPDU(aes: aes, apduHeader: apduHeader, apduData: nil)
        sendAPDU(tag, aes: aes, apdus: apdus)
    }
```
