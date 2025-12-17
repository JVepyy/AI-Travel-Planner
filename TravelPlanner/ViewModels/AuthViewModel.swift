//
//  AuthViewModel.swift
//  TravelPlanner
//
//  Manages authentication state and logic
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService = AuthenticationService.shared
    
    init() {
        checkAuthStatus()
    }
    
    // Check if user is already logged in
    func checkAuthStatus() {
        isAuthenticated = authService.isLoggedIn()
        if isAuthenticated {
            currentUser = authService.getUser()
        }
    }
    
    // Login
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.login(email: email, password: password)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = "Login failed. Please try again."
        }
        
        isLoading = false
    }
    
    // Register
    func register(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.register(email: email, password: password, name: name)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = "Registration failed. Please try again."
        }
        
        isLoading = false
    }
    
    // Logout
    func logout() {
        authService.logout()
        currentUser = nil
        isAuthenticated = false
    }
}

