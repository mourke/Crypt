//
//  User.swift
//  Crypt
//
//  Created by Mark Bourke on 20/04/2021.
//

import Foundation

struct User: Hashable {
    let name: String
    let key: SecKey
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(key)
    }
}
