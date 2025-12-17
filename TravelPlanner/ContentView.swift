//
//  ContentView.swift
//  TravelPlanner
//
//  Main content view - handles navigation between Welcome and Home
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView(viewModel: authViewModel)
            } else {
                WelcomeView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
