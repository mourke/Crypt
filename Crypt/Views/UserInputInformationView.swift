//
//  UserInputInformationView.swift
//  Crypt
//
//  Created by Mark Bourke on 22/04/2021.
//

import SwiftUI
import UniformTypeIdentifiers.UTType

struct UserInputInformationView: View {
    
    enum Error: LocalizedError {
        case usernameTooLong
        case usernameEmpty
        case usernameContainsSpaces
        case unsupportedCert
        case noCertificate
        
        var errorDescription: String? {
            switch self {
            case .usernameTooLong:
                return "Username too long"
            case .usernameEmpty:
                return "Empty username"
            case .usernameContainsSpaces:
                return "Username contains spaces"
            case .unsupportedCert:
                return "Unsupported certificate type"
            case .noCertificate:
                return "No certificate"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .usernameTooLong:
                return "The maximum number of characters your username can be is 82"
            case .usernameEmpty:
                return "Username field must not be empty"
            case .usernameContainsSpaces:
                return "Username must not contain spaces"
            case .unsupportedCert:
                return "The specified certificate cannot be used to decrypt. Are you sure this is a public key cert?"
            case .noCertificate:
                return "You must select a certificate to continue"
            }
        }
    }
    
    @Environment(\.presentationMode) var presentationMode
    @State private var username = ""
    @State private var certificate: URL?
    
    var acceptsUsername: Bool = true
    let action: ((User) -> Void)?
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            if acceptsUsername {
                TextField("Username", text: $username)
            }
            HStack {
                TextField("/path/to/cert", text: Binding(get: {
                    return self.certificate?.path ?? ""
                }, set: {
                    self.certificate = URL(string: $0)
                }))
                .disabled(true) // only add through NSOpenPanel
                
                Button("...") {
                    let dialog = NSOpenPanel()
                    
                    dialog.allowsMultipleSelection = false
                    dialog.canChooseDirectories = false
                    dialog.allowedContentTypes = [UTType.x509Certificate]
                    
                    if dialog.runModal() == .OK {
                        certificate = dialog.url
                    }
                }
                
            }
            
            HStack {
                Button("OK") {
                    do {
                        let key = try sanitiseInputs()
                        let user = User(name: username, key: key)
                        presentationMode.wrappedValue.dismiss()
                        action?(user)
                    } catch let error {
                        NSAlert(error: error).runModal()
                    }
                }
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
        } .padding()
    }
    
    private func sanitiseInputs() throws -> SecKey {
        if acceptsUsername {
            if username.count > 82 {
                throw Error.usernameTooLong
            }
            
            if username.isEmpty {
                throw Error.usernameEmpty
            }
            
            if username.contains(" ") {
                throw Error.usernameContainsSpaces
            }
        }
        
        guard let cert = certificate else {
            throw Error.noCertificate
        }
        
        let key = try KeyManager.shared.certToSecKey(cert: cert)
        if !SecKeyIsAlgorithmSupported(key, .encrypt, encryptionAlgorithm) {
            throw Error.unsupportedCert
        }
        
        return key
    }
}
