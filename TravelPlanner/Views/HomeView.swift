import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showSettings = false
    @State private var showCreatePlan = false
    @State private var plans: [TravelPlan] = []
    @State private var isLoadingPlans = true
    @State private var selectedPlan: TravelPlan?
    
    private let travelPlanService = TravelPlanService.shared
    
    var body: some View {
        ZStack {
            // Background gradient
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
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back,")
                            .font(.satoshi(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(viewModel.currentUser?.name ?? "Traveler")
                            .font(.satoshi(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: { showSettings = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Create New Plan Card
                        Button(action: { showCreatePlan = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 1.0, green: 0.5, blue: 0.2),
                                                    Color(red: 0.9, green: 0.3, blue: 0.5)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Create New Plan")
                                        .font(.satoshi(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Start your next adventure")
                                        .font(.satoshi(size: 14, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Your Plans Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 20))
                                Text("Your Plans")
                                    .font(.satoshi(size: 22, weight: .bold))
                                
                                Spacer()
                                
                                Text("\(plans.count)")
                                    .font(.satoshi(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                    )
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            
                            if isLoadingPlans {
                                // Loading state
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    
                                    Text("Loading your plans...")
                                        .font(.satoshi(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else if plans.isEmpty {
                                // Empty state
                                VStack(spacing: 16) {
                                    Image(systemName: "map")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    VStack(spacing: 8) {
                                        Text("No plans yet")
                                            .font(.satoshi(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text("Create your first travel plan above!")
                                            .font(.satoshi(size: 14, weight: .regular))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .padding(.horizontal, 24)
                            } else {
                                // Plans list
                                VStack(spacing: 12) {
                                    ForEach(plans) { plan in
                                        PlanHistoryCard(plan: plan)
                                            .onTapGesture {
                                                selectedPlan = plan
                                            }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showCreatePlan) {
            CreateFirstPlanView(
                hasCreatedFirstPlan: .constant(true),
                onDismiss: { showCreatePlan = false },
                onPlanCreated: { newPlan in
                    plans.insert(newPlan, at: 0)
                }
            )
            .environmentObject(viewModel)
        }
        .fullScreenCover(item: $selectedPlan) { plan in
            TravelPlanView(plan: plan)
        }
        .onAppear {
            loadPlans()
        }
    }
    
    private func loadPlans() {
        guard let userId = viewModel.currentUser?.id else {
            isLoadingPlans = false
            return
        }
        
        Task {
            do {
                plans = try await travelPlanService.getUserPlans(userId: userId)
            } catch {
                print("Error loading plans: \(error)")
            }
            isLoadingPlans = false
        }
    }
}

// MARK: - Plan History Card
struct PlanHistoryCard: View {
    let plan: TravelPlan
    
    var body: some View {
        HStack(spacing: 16) {
            // Flag or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                if let flag = plan.flagEmoji {
                    Text(flag)
                        .font(.system(size: 28))
                } else {
                    Image(systemName: "airplane")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.formattedName)
                    .font(.satoshi(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(formatDateRange(start: plan.startDate, end: plan.endDate))
                            .font(.satoshi(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 12))
                        Text("\(plan.days.count) days")
                            .font(.satoshi(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var editedName: String = ""
    @State private var isEditingName = false
    @State private var showLogoutConfirm = false
    
    var body: some View {
        NavigationView {
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Section
                        VStack(spacing: 16) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Text(String((viewModel.currentUser?.name ?? "T").prefix(1)).uppercased())
                                    .font(.satoshi(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // Name
                            if isEditingName {
                                HStack(spacing: 12) {
                                    TextField("", text: $editedName)
                                        .font(.satoshi(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.15))
                                        )
                                    
                                    Button(action: {
                                        // Save name
                                        // TODO: Implement name update in AuthService
                                        isEditingName = false
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 40)
                            } else {
                                HStack(spacing: 8) {
                                    Text(viewModel.currentUser?.name ?? "Traveler")
                                        .font(.satoshi(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Button(action: {
                                        editedName = viewModel.currentUser?.name ?? ""
                                        isEditingName = true
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            
                            Text(viewModel.currentUser?.email ?? "")
                                .font(.satoshi(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 40)
                        
                        // Settings Options
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                subtitle: "Manage alerts"
                            )
                            
                            SettingsRow(
                                icon: "lock.fill",
                                title: "Privacy",
                                subtitle: "Data & security"
                            )
                            
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: "Help & Support",
                                subtitle: "Get assistance"
                            )
                            
                            SettingsRow(
                                icon: "info.circle.fill",
                                title: "About",
                                subtitle: "Version 1.0.0"
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Logout Button
                        Button(action: { showLogoutConfirm = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18))
                                Text("Log Out")
                                    .font(.satoshi(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.8))
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 30)
                        
                        Spacer()
                            .frame(height: 50)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .alert("Log Out?", isPresented: $showLogoutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    viewModel.logout()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.satoshi(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.satoshi(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.1))
        )
    }
}

