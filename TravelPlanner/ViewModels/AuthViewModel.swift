//
//  AuthViewModel.swift
//  TravelPlanner
//
//  Manages authentication state and logic
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var shouldShowOnboarding = false
    
    private let authService = AuthenticationService.shared
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        isLoading = true
        
        if authService.isLoggedIn() {
            Task {
                do {
                    let user = try await authService.getUser()
                    
                    // If user document doesn't exist in Firestore, sign them out
                    // This ensures users must explicitly log in
                    if user == nil {
                        print("User document not found in Firestore - signing out to require fresh login")
                        currentUser = nil
                        isAuthenticated = false
                        try? authService.logout()
                        isLoading = false
                        return
                    }
                    
                    // User document exists - proceed with authentication
                    currentUser = user
                    isAuthenticated = true
                    shouldShowOnboarding = !authService.hasSeenOnboarding()
                } catch {
                    print("Error getting user: \(error)")
                    currentUser = nil
                    isAuthenticated = false
                    try? authService.logout()
                }
                isLoading = false
            }
        } else {
            currentUser = nil
            isAuthenticated = false
            isLoading = false
        }
    }
    
    func loginWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let credential = try await AppleSignInManager.shared.signIn()
            let user = try await authService.loginWithApple(credential: credential)
            currentUser = user
            shouldShowOnboarding = !authService.hasSeenOnboarding()
            isAuthenticated = true
        } catch {
            errorMessage = "Apple Sign In failed. Please try again."
            print("Apple Sign In Error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func loginWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let credential = try await GoogleSignInManager.shared.signIn()
            let user = try await authService.loginWithGoogle(credential: credential)
            currentUser = user
            shouldShowOnboarding = !authService.hasSeenOnboarding()
            isAuthenticated = true
        } catch {
            errorMessage = "Google Sign In failed. Please try again."
            print("Google Sign In Error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func logout() {
        do {
            try authService.logout()
            currentUser = nil
            isAuthenticated = false
            shouldShowOnboarding = false
        } catch {
            errorMessage = "Logout failed. Please try again."
        }
    }
    
    func finishOnboarding() {
        authService.setOnboardingSeen()
        shouldShowOnboarding = false
    }
}

