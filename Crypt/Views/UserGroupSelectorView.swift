//
//  UserGroupSelectorView.swift
//  Crypt
//
//  Created by Mark Bourke on 20/04/2021.
//

import SwiftUI

struct UserGroupSelectorView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    let checkboxes: Bool
    @State var users: Set<User>
    let action: ((Set<User>) -> Void)?
    
    @State var showUserPicker: Bool = false
    @State var selectedUsers: Set<User> = []
    

    init(checkboxes: Bool, users: Set<User>, action: ((Set<User>) -> Void)?) {
        self.checkboxes = checkboxes
        self.action = action
        _users = State(initialValue: users)
        
        if checkboxes { // select all users
            _selectedUsers = State(initialValue: users)
        }
    }

    var body: some View {
        VStack {
            UserTableView(selectedUsers: $selectedUsers,
                          checkboxes: checkboxes, dataSource: $users)
                .frame(minWidth: 300, minHeight: 300)
            HStack {
                if !checkboxes {
                    Button("+") {
                        showUserPicker = true
                    }
                    
                    Button("-") {
                        selectedUsers.forEach { users.remove($0) }
                        selectedUsers.removeAll()
                    }
                    .disabled(selectedUsers.isEmpty)
                } else {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                Spacer()
                
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                    action?(checkboxes ? selectedUsers : users)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        } .sheet(isPresented: $showUserPicker) {
            UserInputInformationView() { (user) in
                users.insert(user)
            }
        }
    }
}
