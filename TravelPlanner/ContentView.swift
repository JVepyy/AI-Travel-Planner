import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var hasCreatedFirstPlan: Bool? = nil // nil = still checking
    
    var body: some View {
        ZStack {
            // Show loading if: still loading auth, or authenticated but no user yet, or checking plans
            if authViewModel.isLoading || 
               (authViewModel.isAuthenticated && authViewModel.currentUser == nil) ||
               (authViewModel.isAuthenticated && authViewModel.currentUser != nil && hasCreatedFirstPlan == nil) {
                LoadingView()
            } else {
                Group {
                    if authViewModel.isAuthenticated && authViewModel.currentUser != nil {
                        // User is authenticated and loaded
                        if authViewModel.shouldShowOnboarding {
                            OnboardingView(showOnboarding: .constant(true))
                                .environmentObject(authViewModel)
                        } else if hasCreatedFirstPlan == false {
                            CreateFirstPlanView(hasCreatedFirstPlan: Binding(
                                get: { hasCreatedFirstPlan ?? false },
                                set: { hasCreatedFirstPlan = $0 }
                            ))
                            .environmentObject(authViewModel)
                        } else {
                            NavigationView {
                                HomeView(viewModel: authViewModel)
                            }
                        }
                    } else {
                        // Not authenticated - show login
                        WelcomeView()
                            .environmentObject(authViewModel)
                    }
                }
            }
        }
        .onAppear {
            print("=== CONTENTVIEW APPEARED ===")
            print("isLoading: \(authViewModel.isLoading)")
            print("isAuthenticated: \(authViewModel.isAuthenticated)")
            print("currentUser: \(String(describing: authViewModel.currentUser))")
            
            if !authViewModel.isLoading && authViewModel.isAuthenticated {
                print("Calling checkIfUserHasPlans from onAppear")
                checkIfUserHasPlans()
            }
        }
        .onChange(of: authViewModel.currentUser) { user in
            print("=== CURRENT USER CHANGED ===")
            print("New user: \(String(describing: user))")
            if user != nil {
                print("Calling checkIfUserHasPlans from onChange(currentUser)")
                checkIfUserHasPlans()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { isAuth in
            print("=== AUTHENTICATION CHANGED ===")
            print("isAuthenticated: \(isAuth)")
            if !isAuth {
                hasCreatedFirstPlan = nil
            }
            // Don't check plans here - wait for currentUser to be set
        }
        .onChange(of: authViewModel.isLoading) { isLoading in
            print("=== LOADING CHANGED ===")
            print("isLoading: \(isLoading)")
            // Don't check plans here - wait for currentUser to be set
        }
    }
    
    private func checkIfUserHasPlans() {
        print("=== CHECK IF USER HAS PLANS ===")
        print("currentUser: \(String(describing: authViewModel.currentUser))")
        print("currentUser.id: \(authViewModel.currentUser?.id ?? "NIL")")
        
        guard let userId = authViewModel.currentUser?.id else {
            print("ERROR: No userId available!")
            hasCreatedFirstPlan = false
            return
        }
        
        print("Checking plans for userId: \(userId)")
        
        Task {
            do {
                let plans = try await TravelPlanService.shared.getUserPlans(userId: userId)
                await MainActor.run {
                    hasCreatedFirstPlan = !plans.isEmpty
                    print("=== PLANS CHECK RESULT ===")
                    print("Found \(plans.count) plans")
                    print("hasCreatedFirstPlan = \(hasCreatedFirstPlan ?? false)")
                    for plan in plans {
                        print("  - Plan: \(plan.destination), userId: \(plan.userId)")
                    }
                }
            } catch {
                print("=== PLANS CHECK ERROR ===")
                print("Error: \(error)")
                await MainActor.run {
                    hasCreatedFirstPlan = false
                }
            }
        }
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
                Spacer()
                 .frame(height: 240)                   
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Travel Planner")
                    .font(.satoshi(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
