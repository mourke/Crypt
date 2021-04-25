//
//  EncryptionHandler.swift
//  Crypt
//
//  Created by Mark Bourke on 20/04/2021.
//

import Foundation
import CryptoKit
import OSLog


fileprivate let DATA_ENCODING: String.Encoding = .utf8
fileprivate let HEADER_ARMOUR_START = "=======================ALLOWED USERS=======================".data(using: DATA_ENCODING)!
fileprivate let HEADER_ARMOUR_END = "============================END============================".data(using: DATA_ENCODING)!
fileprivate let LINE_BREAK: UInt8 = "\n".data(using: DATA_ENCODING)!.first!

let encryptionAlgorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512
let signingAlgorithm: SecKeyAlgorithm = .rsaSignatureMessagePSSSHA512


struct EncryptionHandler {
    
    enum EncryptionError: LocalizedError {
        case unableToWriteFile
        case failedToEncryptData
        case failedToCreateSignature
        
        var errorDescription: String? {
            switch self {
            case .unableToWriteFile:
                return "Unable to write to destination"
            case .failedToEncryptData:
                return "Failed to encrypt file data"
            case .failedToCreateSignature:
                return "Failed to create signature"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unableToWriteFile:
                return "The selected destination might not exist anymore, your computer could be out of storage, or the permissions might have changed."
            case .failedToEncryptData:
                return "There was a cipher error when trying to encrypt the data."
            case .failedToCreateSignature:
                return "The file signature could not be created. The file may be too big."
            }
        }
    }
    
    enum DecryptionError: LocalizedError {
        case unableToWriteFile
        case insufficientPermissions
        case fileWasTamperedWith
        case malformedFile
        
        var errorDescription: String? {
            switch self {
            case .unableToWriteFile:
                return "Unable to write to destination"
            case .insufficientPermissions:
                return "Insufficient permissions"
            case .fileWasTamperedWith:
                return "Signature mismatch"
            case .malformedFile:
                return "Malformed file"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unableToWriteFile:
                return "The selected destination might not exist anymore, your computer could be out of storage, or the permissions might have changed."
            case .insufficientPermissions:
                return "It looks like you aren't in the secure group of the user that encrypted this file."
            case .fileWasTamperedWith:
                return "The signature of the file does not match the data. The file could've been tampered with or the wrong file owner was provided."
            case .malformedFile:
                return "The file was corrupted and is now unsalvageable."
            }
        }
    }
    
    /**
     Encrypts a given file such that only the specified users will be able to decrypt it.
     
     - Parameter file:          The file to be encrypted.
     - Parameter destination:   The destination **folder**. This must already exist.
     - Parameter owner:         The owner of the file. The `key` attribute **must** be a *private* key. This is used to create a signature to verify the integrity of the file.
     
     - Parameter users:         An array of the users you want to be able to open the file. The `key` attribute of each user **must** be a *public* key. The owner should be added to this array otherwise they will not be able to decrypt the final file.
     
     - Returns: The location of the decrypted file. This will have the same name as the input but with the file extension ".crypt".
     */
    @discardableResult
    static func encrypt(file: URL,
                        destination: URL,
                        owner: User,
                        users: Set<User>) throws -> URL {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory)
        precondition(exists && isDirectory.boolValue)
        
        let output = destination.appendingPathComponent(file.lastPathComponent).appendingPathExtension(PathComponent) // keep original file extension too so we know what to save it as when decrypting
        
        // this is the key we use to encrypt the message
        // we're going to store the decryption key in the file
        let key = SymmetricKey(size: .bits256)
        
        var data = HEADER_ARMOUR_START
        
        for user in users {
            precondition(!user.name.contains(" "), "Username must not contain spaces") // sanitise input as we are using the space character to denote the key. this is done when the application takes input and the only way it won't is if there is a bad error.
            
            let allowedUser = "\(user.name) \(key.withUnsafeBytes { Data($0).base64EncodedString() })" // store the decryption key here
            
            precondition(SecKeyIsAlgorithmSupported(user.key, .encrypt, encryptionAlgorithm), "Unable to encrypt using the \(encryptionAlgorithm.rawValue) algorithm with \(user.name)'s key. Make sure this is the private key and not the public key.")
            
            precondition(allowedUser.count < (SecKeyGetBlockSize(user.key) - 130), "Username too long") // this is sanitised on the input.
            
            var error: Unmanaged<CFError>?
            guard let signature = SecKeyCreateEncryptedData(user.key,
                                                            encryptionAlgorithm,
                                      allowedUser.data(using: DATA_ENCODING)! as CFData,
                                      &error) as Data? else {
                let reason = error?.takeRetainedValue().localizedDescription ?? "An unknown error occurred."
                preconditionFailure("Could not encrypt data for: \(user.name). \(reason)")
            }
            
            data.append(LINE_BREAK)
            data += signature.base64EncodedData()
        }
        
        data.append(LINE_BREAK)
        data += HEADER_ARMOUR_END
        data.append(LINE_BREAK)

        let fileData: Data
        
        do {
            fileData = try Data(contentsOf: file)
        } catch let e {
            os_log(.error, "%s", e.localizedDescription)
            preconditionFailure("Could not read file")
        }
        
        do {
            data += try ChaChaPoly.seal(fileData, using: key).combined.base64EncodedData()
        } catch let e {
            os_log(.error, "%s", e.localizedDescription)
            throw EncryptionError.failedToEncryptData
        }
        
        var error: Unmanaged<CFError>?
        guard var signature = SecKeyCreateSignature(owner.key, signingAlgorithm, data as CFData, &error) as Data? else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "An unknown error occurred."
            os_log(.error, "Failed to create signature. %s", reason)
            throw EncryptionError.failedToCreateSignature
        }
        signature = signature.base64EncodedData()
        signature.append(LINE_BREAK)
        data = signature + data
        
        do {
            try data.write(to: output)
        } catch let e {
            os_log(.error, "%s", e.localizedDescription)
            throw EncryptionError.unableToWriteFile
        }
        
        return output
    }
    
    /**
     Decrypts a given file, if possible.
     
     - Parameter file:          The file to be decrypted.
     - Parameter destination:   The destination **folder**. This must already exist.
     - Parameter owner:         The owner of the file. The `key` attribute **must** be the *public* key. This is used to validate the signature to verify the integrity of the file.
     - Parameter user:          The current user trying to decrypt the file. The `key` attribute of each user **must** be a *private* key.
     
     - Throws: Errors if the file has been modified by an external source or if incorrect parameters have been provided.
     
     - Returns: The destination of the decrypted file. This will be with the original file extension (hopefully).
     */
    @discardableResult
    static func decrypt(file: URL,
                        destination: URL,
                        fileOwner owner: User,
                        currentUser user: User) throws -> URL {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory)
        precondition(exists && isDirectory.boolValue)
        
        var output = destination.appendingPathComponent(file.lastPathComponent).deletingPathExtension()
        if output.pathExtension.isEmpty {
            output.appendPathExtension("txt") // if the file name was altered, default to .txt and let the user figure out the path
        }
        
        var fileData: Data
        
        do {
            fileData = try Data(contentsOf: file)
        } catch let e {
            os_log(.error, "%s", e.localizedDescription)
            preconditionFailure("Unable to open file") // should be sanitised and checked for existance before this method is called
        }
        
        var base64SignatureData = Data()
        while fileData.first != LINE_BREAK {
            base64SignatureData.append(fileData.removeFirst())
        }
        fileData.removeFirst() // remove line break
        guard let signatureData = Data(base64Encoded: base64SignatureData) else {
            os_log(.error, "First line of file did not start with base64 encoded hashed signature.")
            throw DecryptionError.malformedFile
        }

        var error: Unmanaged<CFError>?
        guard SecKeyVerifySignature(owner.key, signingAlgorithm, fileData as CFData, signatureData as CFData, &error) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "An unknown error occurred."
            os_log(.info, "Signature mismatch. %s", reason)
            throw DecryptionError.fileWasTamperedWith
        }

        var lines = fileData.split(separator: LINE_BREAK)
        if lines.removeFirst() != HEADER_ARMOUR_START {
            os_log(.error, "Second line of file did not start with header mast as it should.")
            throw DecryptionError.malformedFile
        }
        
        var contentsDecryptionKey: SymmetricKey?
        
        while lines.first != HEADER_ARMOUR_END {
            guard !lines.isEmpty else { // if lines is empty, the header mast hasn't been closed
                os_log(.error, "Header mast not closed")
                throw DecryptionError.malformedFile
            }
            let cipherText = Data(base64Encoded: lines.removeFirst())!
            
            precondition(SecKeyIsAlgorithmSupported(user.key, .decrypt, encryptionAlgorithm), "Unable to decrypt using the \(encryptionAlgorithm.rawValue) algorithm with \(user.name)'s key. Make sure this is the private key and not the public key.")
            
            guard cipherText.count == SecKeyGetBlockSize(user.key) else {
                os_log(.info, "Cipher text is wrong size. Could have been encrypted with a different length key.")
                continue // try next one
            }
            
            var error: Unmanaged<CFError>?
            guard let clearText = SecKeyCreateDecryptedData(user.key,
                                                            encryptionAlgorithm,
                                                            cipherText as CFData,
                                                            &error) as Data? else {
                let reason = error?.takeRetainedValue().localizedDescription ?? "An unknown error occurred."
                os_log(.info, "Failed to decrypt cypher text with private key. \(reason)")
                continue // wrong key. try the next one
            }
            let parts = String(data: clearText, encoding: DATA_ENCODING)!.split(separator: " ")
            if parts.count != 2 { // should be user`space`decryptionKey. if it isn't, the input could be garbled due to file corruption or just that the wrong key was used; in the latter we must keep searching
                os_log(.info, "\(parts.count) parts found.")
                continue
            }
            
            let username = parts[0]
            precondition(!user.name.contains(" "), "Username must not contain spaces") // sanitise input as we are using the space character to denote the key. this is done when the application takes input and the only way it won't is if there is a bad error.
            let key = parts[1]
            
            if username != user.name { // they would only be equal if the right decryption key is used. if they're not, keep looking. the odds of two users with the same name having an overlap is infinitely small and therefore doesn't matter
                os_log(.info, "Username mismatch. Found: \(username). Looking for: \(user.name)")
                continue
            }
            
            // we have permission!
            
            contentsDecryptionKey = SymmetricKey(data: Data(base64Encoded: String(key))!)
            
            break // the odds of decrypting a random signature and the output being your exact username but not being the correct key is infinitely small for this algorithm as decrypting similar strings leads to vastly different signatures and therefore doesn't matter. if this turns out to be a problem, just remove this break
        }
        
        guard let decryptionKey = contentsDecryptionKey else {
            throw DecryptionError.insufficientPermissions
        }
        
        // just in case we didn't reach the end before.
        while lines.first != HEADER_ARMOUR_END {
            guard !lines.isEmpty else { // if lines is empty, the header mast hasn't been closed
                os_log(.error, "Header mast not closed")
                throw DecryptionError.malformedFile
            }
            lines.removeFirst()
        }
        
        
        let combined = Data(base64Encoded: lines.last!)!
        let decryptedContents: Data
        
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: combined)
            decryptedContents = try ChaChaPoly.open(sealedBox, using: decryptionKey)
        } catch let e {
            os_log(.error, "%s", e.localizedDescription)
            throw DecryptionError.malformedFile
        }
        
        do {
            try decryptedContents.write(to: output)
        } catch let e {
            os_log(.error, "%s", e.localizedDescription)
            throw EncryptionError.unableToWriteFile
        }
        
        return output
    }
}
