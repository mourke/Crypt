//
//  UserTableView.swift
//  Crypt
//
//  Created by Mark Bourke on 24/04/2021.
//

import SwiftUI
import AppKit

struct UserTableView: NSViewControllerRepresentable, UserTableViewControllerDelegate {
    
    typealias NSViewControllerType = UserTableViewController
    
    @Binding var selectedUsers: Set<User>
    let checkboxes: Bool
    @Binding var dataSource: Set<User>
    
    func updateNSViewController(_ nsViewController: NSViewControllerType, context: Context) {
        nsViewController.items = dataSource
        nsViewController.reloadItems()
    }
    
    func tableView(_ tableView: NSTableView, didSelectRows indexSet: IndexSet) {
        guard !indexSet.isEmpty else {
            selectedUsers.removeAll()
            return
        }
        
        var users = Set<User>()
        let dataSource = Array(self.dataSource)
        
        indexSet.forEach {
            users.insert(dataSource[$0])
        }
        
        selectedUsers = users
    }
    
    func checkboxWasClicked(enabled: Bool, index: Int) {
        let user = Array(self.dataSource)[index]
        
        if enabled {
            selectedUsers.insert(user)
        } else {
            selectedUsers.remove(user)
        }
    }
    
    func makeNSViewController(context: Context) -> NSViewControllerType {
        let tableViewController = NSViewControllerType(checkboxes: checkboxes)
        tableViewController.delegate = self
        return tableViewController
    }
}
