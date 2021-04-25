//
//  FileLoaderViewModel.swift
//  Crypt
//
//  Created by Mark Bourke on 22/04/2021.
//

import Foundation
import SwiftUI
import AppKit

extension FileLoaderView {
    
    class ViewModel: ObservableObject {
        
        @Published var fileURL: URL?
        @Published var activeSheet: Sheets?
        var users: Set<User> = []
        
        var isEncrypting: Bool {
            return fileURL?.pathExtension != PathComponent
        }
        
        private var destinationURL: URL?
        
        var fileImage: Image? {
            guard let url = fileURL else {
                return nil
            }
            let image = NSWorkspace.shared.icon(forFile: url.path)
            image.size = NSSize(width: 100, height: 100)
            return Image(nsImage: image)
        }
        
        var fileName: String? {
            guard let url = fileURL else {
                return nil
            }
            return url.lastPathComponent
        }
        
        func exportCert() {
            let dialog = NSSavePanel()
            
            dialog.title = "Choose a destination for your public key cert"
            dialog.showsResizeIndicator = false
            dialog.allowedFileTypes = ["pem"]
            dialog.allowsOtherFileTypes = false
            
            if (dialog.runModal() == .OK) {
                let url = dialog.url!
                do {
                    try KeyManager.shared.secKeyToCert(key: KeyManager.shared.publicKey,
                                                       destination: url)
                    let success = NSAlert()
                    success.messageText = "Successfully exported cert"
                    success.informativeText = "File location: \(url.path)"
                    success.icon = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                    success.runModal()
                } catch let error {
                    NSAlert(error: error).runModal()
                }
            }
        }
        
        func openFileDialogue() {
            let dialog = NSOpenPanel() // use this so the user can't specify a name
            dialog.prompt = "Save"
            dialog.title = "Choose a destination for your encrypted file"
            dialog.showsResizeIndicator = false
            dialog.allowsMultipleSelection = false
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = false

            if (dialog.runModal() == .OK) {
                destinationURL = dialog.url!
                
                if isEncrypting { // if we're encrypting, ask the user who they want to have access to this file
                    activeSheet = .confirmGroupSelector
                } else { // if they're decrypting ask who the owner is
                    activeSheet = .askOwner
                }
            }
        }
        
        func encrypt(for users: Set<User>) {
            guard let url = fileURL, let destination = destinationURL else {
                preconditionFailure("FileURL or destinationURL was nil")
            }
            
            var users = users
            users.insert(PublicMe) // make sure owner can decrypt
            
            do {
                let fileURL = try EncryptionHandler.encrypt(file: url,
                                                            destination: destination,
                                                            owner: PrivateMe,
                                                            users: users)
                
                let success = NSAlert()
                success.messageText = "Successfully encrypted file"
                success.informativeText = "File location: \(fileURL.path)"
                success.icon = NSImage(systemSymbolName: "lock.doc", accessibilityDescription: nil)
                success.runModal()
            } catch let error {
                NSAlert(error: error).runModal()
            }
        }
        
        func decrypt(owner: User) {
            guard let url = fileURL, let destination = destinationURL else {
                preconditionFailure("FileURL or destinationURL was nil")
            }
            
            do {
                let fileURL = try EncryptionHandler.decrypt(file: url,
                                                            destination: destination,
                                                            fileOwner: owner,
                                                            currentUser: PrivateMe)
                let success = NSAlert()
                success.messageText = "Successfully decrypted file"
                success.informativeText = "File location: \(fileURL.path)"
                success.icon = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
                success.runModal()
            } catch let error {
                NSAlert(error: error).runModal()
            }
        }
    }
}
