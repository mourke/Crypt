//
//  KeyManager.swift
//  Crypt
//
//  Created by Mark Bourke on 22/04/2021.
//

import Foundation
import Security.SecImportExport
import OSLog

struct KeyManager {
    
    /**
    This class should be used to access the current user's public and private keys. The keys are stored and encrypted in the operating system keychain. If no keys exist, they will be generated automatically and stored in the keychain.
     */
    static let shared = KeyManager()
    
    let publicKey: SecKey
    let privateKey: SecKey
    
    enum ImportError: LocalizedError {
        case invalidCert
        
        var errorDescription: String? {
            switch self {
            case .invalidCert:
                return "Invalid certificate"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .invalidCert:
                return "Check the integrity of the file."
            }
        }
    }
    
    enum ExportError: LocalizedError {
        case invalidKey
        
        var errorDescription: String? {
            switch self {
            case .invalidKey:
                return "Invalid key"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .invalidKey:
                return "Could not export specified key to a pem cert."
            }
        }
    }
    
    private init() {
        let tag = "com.mourke.crypt".data(using: .utf8)!
        let attributes = [
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: "Crypt Private Key",
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: tag
        ] as CFDictionary
        var publicKey, privateKey: SecKey!
        var key: CFTypeRef?
        SecItemCopyMatching(attributes, &key)
        
        
        if let key = key {
            privateKey = (key as! SecKey)
            publicKey = SecKeyCopyPublicKey(privateKey)
        } else {
            let attributes = [
                kSecClass as String: kSecClassKey,
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeySizeInBits as String: 2048,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrCanDecrypt as String: true,
                    kSecAttrIsPermanent as String: true,
                    kSecAttrLabel as String: "Crypt Private Key",
                    kSecAttrApplicationTag as String: tag
                ],
                kSecPublicKeyAttrs as String: [
                    kSecAttrLabel as String: "Crypt Public Key",
                    kSecAttrApplicationTag as String: tag
                ]
            ] as CFDictionary
            let status = SecKeyGeneratePair(attributes, &publicKey, &privateKey)
            guard status == errSecSuccess else {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
                fatalError(error.localizedDescription)
            }
        }
        
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
    
    /**
     Convert a .pem or .cert into a SecKey keychain object.
     
     - Parameter url:   The location on disk of the cert.
     
     - Throws: Errors if the cert is not valid or if it doesn't exist on disk.
     
     - Returns: A SecKey not stored in the keychain.
     */
    func certToSecKey(cert url: URL) throws -> SecKey {
        let data = try Data(contentsOf: url)
        var items: CFArray!
        var format: SecExternalFormat = .formatOpenSSL
        var type: SecExternalItemType = .itemTypePublicKey
        
        let status = SecItemImport(data as CFData,
                                   url.lastPathComponent as CFString,
                                   &format, &type, [], nil, nil, &items)
        guard status == errSecSuccess else {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            os_log(.error, "%s", error.localizedDescription)
            throw ImportError.invalidCert
        }
        
        guard let keys = items as? Array<SecKey>,
              let key = keys.first else {
            os_log(.error, "Key was not of type SecKey")
            throw ImportError.invalidCert
        }
        
        return key
    }
    
    /**
     Exports a keychain key (public key, private key, cert) to disk in the .pem format.
     
     - Parameter key:   The keychain object to be exported.
     - Parameter url:   The destination of the cert when exported.
     
     - Throws:  Errors if the key is invalid or if the cert was not able to be written to disk.
     */
    func secKeyToCert(key: SecKey, destination url: URL) throws {
        var cfData: CFData!
        let status = SecItemExport(publicKey, .formatPEMSequence, .pemArmour, nil, &cfData)
        guard status == errSecSuccess else {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            os_log(.error, "%s", error.localizedDescription)
            throw ExportError.invalidKey
        }
        
        let data = cfData as Data
        try data.write(to: url)
    }
}
