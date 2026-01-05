import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var hasCreatedFirstPlan = false
    
    var body: some View {
        ZStack {
            if authViewModel.isLoading {
                LoadingView()
            } else {
                NavigationView {
                    Group {
                        if authViewModel.isAuthenticated {
                            if authViewModel.shouldShowOnboarding {
                                OnboardingView(showOnboarding: .constant(true))
                                    .environmentObject(authViewModel)
                            } else if !hasCreatedFirstPlan {
                                CreateFirstPlanView()
                                    .environmentObject(authViewModel)
                            } else {
                                HomeView(viewModel: authViewModel)
                            }
                        } else {
                            WelcomeView()
                                .environmentObject(authViewModel)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authViewModel.isLoading)
        .onAppear {
            checkIfUserHasPlans()
        }
    }
    
    private func checkIfUserHasPlans() {
        // For now, always show CreateFirstPlanView after onboarding
        // Later we'll check Firestore if user has any plans
        hasCreatedFirstPlan = false
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.5, blue: 1.0),
                    Color(red: 0.6, green: 0.3, blue: 0.9),
                    Color(red: 0.9, green: 0.4, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Travel Planner")
                    .font(.satoshi(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    ContentView()
}
