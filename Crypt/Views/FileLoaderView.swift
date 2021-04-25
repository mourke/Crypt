//
//  FileLoaderView.swift
//  Crypt
//
//  Created by Mark Bourke on 19/04/2021.
//

import SwiftUI

struct FileLoaderView: View {
    
    enum Sheets: Identifiable {
        case showGroupSelector, confirmGroupSelector, askOwner
        
        var id: Int {
            hashValue
        }
    }
    
    @ObservedObject var viewModel: ViewModel
    
    private var hasFile: Bool {
        return viewModel.fileURL != nil
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            if viewModel.fileURL != nil {
                viewModel.fileImage!
                Text(viewModel.fileName!)
                    .font(.title3)
            } else {
                Image(systemName: "arrow.down.app")
                    .font(.system(size: 70))
                    .foregroundColor(.gray)
                Text("Drag and drop file")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }
        .toolbar {
            Button(action: viewModel.exportCert) {
                Label("Export Public Key", systemImage: "command")
            }
            
            Button {
                viewModel.fileURL = nil
            } label: {
                Label("Clear", systemImage: "clear")
            } .disabled(!hasFile)
            
            Button {
                viewModel.activeSheet = .showGroupSelector
            } label: {
                Label("Secure Cloud Storage Group", systemImage: "person.2")
            }
            
            Button(action: viewModel.openFileDialogue) {
                Label(viewModel.isEncrypting ? "Encrypt" : "Decrypt",
                      systemImage: viewModel.isEncrypting ? "lock" : "lock.open")
            } .disabled(!hasFile)
        }
        .sheet(item: $viewModel.activeSheet) { (sheet) in
            switch sheet {
            case .showGroupSelector:
                UserGroupSelectorView(checkboxes: false, users: viewModel.users) {  (users) in
                    viewModel.users = users
                }
            case .confirmGroupSelector:
                UserGroupSelectorView(checkboxes: true, users: viewModel.users) { (users) in
                    viewModel.encrypt(for: users)
                }
            case .askOwner:
                UserInputInformationView(acceptsUsername: false) { (user) in
                    viewModel.decrypt(owner: user)
                }
            }
        }
    }
}
