import SwiftUI

struct CreateFirstPlanView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var hasCreatedFirstPlan: Bool
    var onDismiss: (() -> Void)? = nil // Optional close action
    var onPlanCreated: ((TravelPlan) -> Void)? = nil // Callback when plan is created
    
    @State private var currentStage = 0
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 3)
    @State private var budget: BudgetLevel = .moderate
    @State private var specialRequests = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var hasFlexibleDates = false
    @State private var tripDuration: Int = 7
    
    var body: some View {
        Group {
            if isGenerating {
                PlanGenerationLoadingView()
            } else {
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
                    
                    VStack(spacing: 0) {
                        // Header with optional close button
                        HStack {
                            if let dismiss = onDismiss {
                                Button(action: dismiss) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            } else {
                                Spacer()
                                    .frame(width: 28)
                            }
                            
                            Spacer()
                            
                            ProgressBar(currentStage: currentStage, totalStages: 4)
                            
                            Spacer()
                            
                            // Invisible spacer for alignment
                            Spacer()
                                .frame(width: 28)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        
                        TabView(selection: $currentStage) {
                            Stage1DestinationView(destination: $destination, isTextFieldFocused: $isTextFieldFocused)
                                .tag(0)
                            
                            Stage2DatesView(startDate: $startDate, endDate: $endDate, isFlexibleDates: $hasFlexibleDates, duration: $tripDuration)
                                .tag(1)
                            
                            Stage3BudgetView(budget: $budget)
                                .tag(2)
                            
                            Stage4SpecialRequestsView(specialRequests: $specialRequests)
                                .tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.3), value: currentStage)
                        .onChange(of: currentStage) { _ in
                            isTextFieldFocused = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 16) {
                            if currentStage < 3 {
                                Button(action: {
                                    withAnimation {
                                        currentStage += 1
                                    }
                                }) {
                                    Text("Continue")
                                        .font(.satoshi(size: 18, weight: .bold))
                                        .foregroundColor(.clear)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(
                                            Capsule()
                                                .fill(Color.white)
                                        )
                                        .overlay(
                                            Text("Continue")
                                                .font(.satoshi(size: 18, weight: .bold))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(red: 0.3, green: 0.5, blue: 1.0),
                                                            Color(red: 0.6, green: 0.3, blue: 0.9),
                                                            Color(red: 0.9, green: 0.4, blue: 0.6)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        )
                                }
                                .disabled(!canContinue)
                                .opacity(canContinue ? 1 : 0.5)
                                .padding(.horizontal, 32)
                            } else {
                                Button(action: {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    generatePlan()
                                }) {
                                    Text("Generate My Plan")
                                        .font(.satoshi(size: 18, weight: .bold))
                                        .foregroundColor(.clear)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(
                                            Capsule()
                                                .fill(Color.white)
                                        )
                                        .overlay(
                                            Text("Generate My Plan")
                                                .font(.satoshi(size: 18, weight: .bold))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(red: 0.3, green: 0.5, blue: 1.0),
                                                            Color(red: 0.6, green: 0.3, blue: 0.9),
                                                            Color(red: 0.9, green: 0.4, blue: 0.6)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        )
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                        .padding(.bottom, 50)
                    }
                    
                    // Error alert
                    if let error = generationError {
                        VStack {
                            Spacer()
                            ErrorAlertView(
                                message: error,
                                onRetry: {
                                    generationError = nil
                                    generatePlan()
                                },
                                onDismiss: {
                                    generationError = nil
                                }
                            )
                            .padding()
                            Spacer()
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $generatedPlan) { plan in
            TravelPlanView(plan: plan)
                .onDisappear {
                    print("=== TravelPlanView DISAPPEARED ===")
                    print("Setting hasCreatedFirstPlan = true")
                    // Only set this after user dismisses the plan view
                    // This allows them to see the plan first
                    hasCreatedFirstPlan = true
                    
                    // If this was called from HomeView (has onDismiss), dismiss the CreateFirstPlanView too
                    if let dismiss = onDismiss {
                        print("Dismissing CreateFirstPlanView to return to HomeView")
                        dismiss()
                    }
                }
        }
    }
    
    private var canContinue: Bool {
        switch currentStage {
        case 0: return !destination.isEmpty
        case 1: return true
        case 2: return true
        default: return true
        }
    }
    
    @State private var isGenerating = false
    @State private var generatedPlan: TravelPlan?
    @State private var generationError: String?
    
    private func generatePlan() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Prepare plan data
        let planData = PlanRequestData(
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            budget: budget.rawValue,
            specialRequests: specialRequests.isEmpty ? nil : specialRequests,
            isFlexibleDates: hasFlexibleDates,
            duration: tripDuration
        )
        
        isGenerating = true
        generationError = nil
        
        Task {
            do {
                // Call Cloud Function to generate plan with OpenAI
                // Note: The Cloud Function already saves the plan to Firestore
                let plan = try await TravelPlanService.shared.generatePlan(data: planData)
                
                await MainActor.run {
                    print("=== PLAN GENERATED SUCCESSFULLY ===")
                    print("Plan ID: \(plan.id)")
                    print("Plan userId: \(plan.userId)")
                    print("Plan destination: \(plan.destination)")
                    
                    generatedPlan = plan
                    isGenerating = false
                    
                    // Don't set hasCreatedFirstPlan here - wait until TravelPlanView is dismissed
                    // This ensures the plan view is shown first
                    
                    // Notify callback about new plan
                    onPlanCreated?(plan)
                }
            } catch {
                await MainActor.run {
                    generationError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
    
    private func createMockPlan(data: PlanRequestData) -> TravelPlan {
        // This will be replaced with actual API response
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: data.startDate, to: data.endDate).day ?? 1
        
        var dayItineraries: [DayItinerary] = []
        var currentDate = data.startDate
        
        for dayNum in 1...days {
            dayItineraries.append(
                DayItinerary(
                    dayNumber: dayNum,
                    date: currentDate,
                    theme: "Day \(dayNum) Exploration",
                    activities: [
                        Activity(
                            time: "10:00 AM",
                            name: "Explore \(data.destination)",
                            description: "Discover the best of \(data.destination)",
                            duration: "2 hours",
                            cost: "$50",
                            location: "City Center"
                        )
                    ],
                    restaurants: [
                        Restaurant(
                            name: "Local Restaurant",
                            cuisine: "Local",
                            priceRange: data.budget,
                            time: "Lunch",
                            reservation: "Recommended"
                        )
                    ],
                    hiddenGems: ["Secret spot in \(data.destination)"],
                    tip: "Wear comfortable shoes",
                    estimatedDailyCost: "$150"
                )
            )
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return TravelPlan(
            userId: authViewModel.currentUser?.id ?? "",
            destination: data.destination,
            startDate: data.startDate,
            endDate: data.endDate,
            budget: data.budget,
            specialRequests: data.specialRequests,
            days: dayItineraries,
            totalEstimatedCost: "$\(days * 150)",
            highlights: ["Main attraction 1", "Main attraction 2"],
            localTips: ["Learn basic phrases", "Carry cash"]
        )
    }
    
}

struct ProgressBar: View {
    let currentStage: Int
    let totalStages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalStages, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStage ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

struct Stage1DestinationView: View {
    @Binding var destination: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Where do you want to go?")
                        .font(.satoshi(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Let's go somewhere amazing")
                        .font(.satoshi(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Text Field Card
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Paris, Tokyo, New York...", text: $destination)
                        .font(.satoshi(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .focused(isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTextFieldFocused.wrappedValue = false
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.15))
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused.wrappedValue = true
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct Stage2DatesView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @State private var selectedPreset: DatePreset? = nil
    @Binding var isFlexibleDates: Bool
    @Binding var duration: Int
    
    var tripDurationDisplay: Int {
        if let preset = selectedPreset, preset != .specificDate {
            return duration
        } else {
            return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("When's the trip?")
                    .font(.satoshi(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Just a rough idea is fine")
                    .font(.satoshi(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            
            VStack(spacing: 20) {
                // Quick Presets (4 buttons in 2x2 grid)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        PresetDateButton(
                            title: "Next Month",
                            icon: "calendar.badge.plus",
                            isSelected: selectedPreset == .nextMonth
                        ) {
                            togglePreset(.nextMonth)
                        }
                        
                        PresetDateButton(
                            title: "This Summer",
                            icon: "sun.max.fill",
                            isSelected: selectedPreset == .thisSummer
                        ) {
                            togglePreset(.thisSummer)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        PresetDateButton(
                            title: "Anytime",
                            icon: "questionmark.circle.fill",
                            isSelected: selectedPreset == .flexible
                        ) {
                            togglePreset(.flexible)
                        }
                        
                        PresetDateButton(
                            title: "Specific Dates",
                            icon: "calendar.badge.clock",
                            isSelected: selectedPreset == .specificDate
                        ) {
                            togglePreset(.specificDate)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                // Show duration adjuster when first 3 presets are selected
                if let preset = selectedPreset, preset != .specificDate {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            Button(action: {
                                if duration > 1 {
                                    duration -= 1
                                    updateDatesForPreset()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(duration > 1 ? 1 : 0.3))
                            }
                            .disabled(duration <= 1)
                            
                            VStack(spacing: 4) {
                                Text("\(duration)")
                                    .font(.satoshi(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("day\(duration == 1 ? "" : "s") trip")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Button(action: {
                                if duration < 30 {
                                    duration += 1
                                    updateDatesForPreset()
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(duration < 30 ? 1 : 0.3))
                            }
                            .disabled(duration >= 30)
                        }
                    }
                }
                
                // Show date pickers when "specific date" is selected
                if selectedPreset == .specificDate {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("From")
                                        .font(.satoshi(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .tint(.white)
                                        .accentColor(.white)
                                        .environment(\.locale, Locale(identifier: "en_GB"))
                                }
                                .frame(maxWidth: .infinity)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 24)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("To")
                                        .font(.satoshi(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .tint(.white)
                                        .accentColor(.white)
                                        .environment(\.locale, Locale(identifier: "en_GB"))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 32)
                        
                        // Show trip duration for manual dates
                        if tripDurationDisplay > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text("\(tripDurationDisplay) day\(tripDurationDisplay == 1 ? "" : "s") trip")
                                    .font(.satoshi(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func togglePreset(_ preset: DatePreset) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if selectedPreset == preset {
                // Deselect
                selectedPreset = nil
                isFlexibleDates = false
            } else {
                // Select and set dates
                selectedPreset = preset
                isFlexibleDates = (preset == .flexible)
                
                if preset == .specificDate {
                    // Initialize with reasonable defaults for specific dates
                    let calendar = Calendar.current
                    let now = Date()
                    if startDate < now {
                        startDate = calendar.date(byAdding: .day, value: 30, to: now) ?? now
                    }
                    if endDate <= startDate {
                        endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
                    }
                } else if preset == .flexible {
                    // For "Anytime", don't set dates - let AI decide
                    duration = 7 // Default duration, but dates will be determined by AI
                    // Don't call updateDatesForPreset() for flexible
                } else {
                    duration = 7 // Default duration
                    updateDatesForPreset()
                }
            }
        }
    }
    
    private func updateDatesForPreset() {
        guard let preset = selectedPreset, preset != .specificDate else { return }
        let calendar = Calendar.current
        let now = Date()
        
        switch preset {
        case .nextMonth:
            // Start: Beginning of next month
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
               let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) {
                startDate = startOfMonth
                endDate = calendar.date(byAdding: .day, value: duration, to: startDate) ?? startDate
            }
            
        case .thisSummer:
            // Start: June 1st or July 1st (whichever is closer in the future)
            let components = calendar.dateComponents([.year, .month], from: now)
            if let currentYear = components.year {
                if let june1st = calendar.date(from: DateComponents(year: currentYear, month: 6, day: 1)),
                   june1st > now {
                    startDate = june1st
                } else if let july1st = calendar.date(from: DateComponents(year: currentYear, month: 7, day: 1)),
                          july1st > now {
                    startDate = july1st
                } else {
                    // Next year's summer
                    startDate = calendar.date(from: DateComponents(year: currentYear + 1, month: 6, day: 1)) ?? now
                }
                endDate = calendar.date(byAdding: .day, value: duration, to: startDate) ?? startDate
            }
            
        case .flexible:
            // Start: 30 days from now
            startDate = calendar.date(byAdding: .day, value: 30, to: now) ?? now
            endDate = calendar.date(byAdding: .day, value: duration, to: startDate) ?? startDate
            
        case .specificDate:
            break
        }
    }
    
}

enum DatePreset {
    case nextMonth
    case thisSummer
    case flexible
    case specificDate
}


struct PresetDateButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(height: 24)
                
                Text(title)
                    .font(.satoshi(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .frame(height: 18)
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.9))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
        }
        .animation(nil, value: isSelected)
    }
}

struct Stage3BudgetView: View {
    @Binding var budget: BudgetLevel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What's your budget style?")
                    .font(.satoshi(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Choose your spending preference")
                    .font(.satoshi(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            
            VStack(spacing: 16) {
                BudgetButton(
                    icon: "$",
                    title: "Budget-Friendly",
                    subtitle: "Great value for money",
                    isSelected: budget == .budget,
                    action: {
                        budget = .budget
                    }
                )
                
                BudgetButton(
                    icon: "$$",
                    title: "Comfortable",
                    subtitle: "Balanced experience",
                    isSelected: budget == .moderate,
                    action: {
                        budget = .moderate
                    }
                )
                
                BudgetButton(
                    icon: "$$$",
                    title: "Luxury",
                    subtitle: "Premium everything",
                    isSelected: budget == .luxury,
                    action: {
                        budget = .luxury
                    }
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct BudgetButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.system(size: 32))
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.satoshi(size: 18, weight: .bold))
                    Text(subtitle)
                        .font(.satoshi(size: 14, weight: .regular))
                        .opacity(0.8)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.9))
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
        }
        .animation(nil, value: isSelected)
    }
}

struct Stage4SpecialRequestsView: View {
    @Binding var specialRequests: String
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Anything special to add?")
                    .font(.satoshi(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Share anything that matters to you")
                    .font(.satoshi(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            
            ZStack(alignment: .topLeading) {
                if specialRequests.isEmpty {
                    Text("E.g., \"Traveling with 4 friends, we love local food and hiking\"")
                        .font(.satoshi(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                
                TextField("", text: $specialRequests, axis: .vertical)
                    .font(.satoshi(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .frame(minHeight: 120, alignment: .topLeading)
                    .lineLimit(5...10)
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

enum BudgetLevel: String {
    case budget = "Budget-Friendly"
    case moderate = "Moderate"
    case luxury = "Luxury"
}

struct PlanRequestData {
    let destination: String
    let startDate: Date
    let endDate: Date
    let budget: String
    let specialRequests: String?
    let isFlexibleDates: Bool
    let duration: Int
}

struct PlanGenerationLoadingView: View {
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
                
                Text("Planning your adventure...")
                    .font(.satoshi(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
    }
}

struct ErrorAlertView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
            
            Text("Oops!")
                .font(.satoshi(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.satoshi(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.satoshi(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                        )
                }
                
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.satoshi(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    CreateFirstPlanView(hasCreatedFirstPlan: .constant(false))
        .environmentObject(AuthViewModel())
}

