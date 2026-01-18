//
//  User.swift
//  TravelPlanner
//
//  User model
//

import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    var name: String
    let createdAt: Date
    
    init(id: String = UUID().uuidString, email: String, name: String, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.name = name
        self.createdAt = createdAt
    }
}

