//
//  SecKey+CryptoKit.swift
//  Crypt
//
//  Created by Mark Bourke on 22/04/2021.
//

import Foundation
import OSLog
import CryptoKit

protocol CryptoKitKey {
    init<Bytes>(x963Representation: Bytes) throws where Bytes : ContiguousBytes
}

// add any more that you want to support here by extending the class and making it conform to CryptoKitKey

extension P256.Signing.PrivateKey: CryptoKitKey {}
extension P256.Signing.PublicKey: CryptoKitKey {}

extension SecKey {
    
    enum ConversionError: Error {
        case badKey
        case unsupportedKeyType
    }
    
    
    func `as`<T: CryptoKitKey>(cryptoKitKey keyType: T.Type) throws -> T {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(self, &error) as Data? else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "An unknown error occurred."
            os_log(.error, "Cannot extract data. \(reason)")
            throw ConversionError.badKey
        }
        
        let key: T
        
        do {
            key = try .init(x963Representation: keyData)
        } catch let e {
            os_log(.error, "This SecKey cannot be converted to \(String(describing: keyType)). \(e.localizedDescription)")
            throw ConversionError.unsupportedKeyType
        }
        
        return key
    }
}
