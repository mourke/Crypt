//
//  CryptApp.swift
//  Crypt
//
//  Created by Mark Bourke on 19/04/2021.
//

import SwiftUI

let PathComponent = "crypt"

let PublicMe = User(name: "mark", key: KeyManager.shared.publicKey)
let PrivateMe = User(name: "mark", key: KeyManager.shared.privateKey)

@main
struct CryptApp: App {
    
    private var fileLoaderViewModel = FileLoaderView.ViewModel()
    
    var body: some Scene {
        WindowGroup {
            FileLoaderView(viewModel: fileLoaderViewModel)
                .frame(width: 500, height: 500)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    let _ = providers.first?.loadObject(ofClass: URL.self) { (url, error) in
                        DispatchQueue.main.sync {
                            if let error = error {
                                NSAlert(error: error).runModal()
                            } else {
                                self.fileLoaderViewModel.fileURL = url
                            }
                        }
                    }
                    return true
                }
        }
    }
}
