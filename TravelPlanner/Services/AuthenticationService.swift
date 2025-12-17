//
//  AuthenticationService.swift
//  TravelPlanner
//
//  Handles user authentication
//

import Foundation

class AuthenticationService {
    static let shared = AuthenticationService()
    
    private let userDefaultsKey = "authToken"
    private let userDataKey = "userData"
    
    private init() {}
    
    // Save authentication token
    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: userDefaultsKey)
    }
    
    // Get authentication token
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: userDefaultsKey)
    }
    
    // Check if user is logged in
    func isLoggedIn() -> Bool {
        return getToken() != nil
    }
    
    // Save user data
    func saveUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDataKey)
        }
    }
    
    // Get user data
    func getUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    // Logout
    func logout() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userDataKey)
    }
    
    // MARK: - Temporary login (will be replaced with real API)
    func login(email: String, password: String) async throws -> User {
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // For now, create a mock user
        let user = User(email: email, name: email.components(separatedBy: "@").first ?? "User")
        let token = UUID().uuidString
        
        saveToken(token)
        saveUser(user)
        
        return user
    }
    
    // MARK: - Temporary register (will be replaced with real API)
    func register(email: String, password: String, name: String) async throws -> User {
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let user = User(email: email, name: name)
        let token = UUID().uuidString
        
        saveToken(token)
        saveUser(user)
        
        return user
    }
}

