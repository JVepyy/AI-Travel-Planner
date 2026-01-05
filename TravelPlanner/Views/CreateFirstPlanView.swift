import SwiftUI

struct CreateFirstPlanView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentStage = 0
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 3)
    @State private var budget: BudgetLevel = .moderate
    @State private var specialRequests = ""
    @FocusState private var isTextFieldFocused: Bool
    
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
            
            VStack(spacing: 0) {
                ProgressBar(currentStage: currentStage, totalStages: 4)
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
                
                TabView(selection: $currentStage) {
                    Stage1DestinationView(destination: $destination, isTextFieldFocused: $isTextFieldFocused)
                        .tag(0)
                    
                    Stage2DatesView(startDate: $startDate, endDate: $endDate)
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
    
    private func generatePlan() {
        print("🚀 Generating plan for: \(destination)")
        print("📅 Dates: \(startDate) to \(endDate)")
        print("💰 Budget: \(budget.rawValue)")
        print("✨ Special: \(specialRequests)")
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
    @State private var customDuration: Int = 7
    
    var tripDuration: Int {
        if selectedPreset != nil {
            return customDuration
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
                // Quick Presets (3 buttons)
                VStack(spacing: 12) {
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
                    
                    PresetDateButton(
                        title: "I'm Flexible",
                        icon: "sparkles",
                        isSelected: selectedPreset == .flexible
                    ) {
                        togglePreset(.flexible)
                    }
                }
                .padding(.horizontal, 32)
                
                // Show duration adjuster when preset is selected
                if selectedPreset != nil {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            Button(action: {
                                if customDuration > 1 {
                                    customDuration -= 1
                                    updateDatesForPreset()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(customDuration > 1 ? 1 : 0.3))
                            }
                            .disabled(customDuration <= 1)
                            
                            VStack(spacing: 4) {
                                Text("\(customDuration)")
                                    .font(.satoshi(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("day\(customDuration == 1 ? "" : "s") trip")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Button(action: {
                                if customDuration < 30 {
                                    customDuration += 1
                                    updateDatesForPreset()
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(customDuration < 30 ? 1 : 0.3))
                            }
                            .disabled(customDuration >= 30)
                        }
                    }
                }
                
                // Show "or" divider and date pickers when no preset selected
                if selectedPreset == nil {
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                        
                        Text("or")
                            .font(.satoshi(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                    
                    // Specific Date Pickers
                    VStack(spacing: 16) {
                        Text("Pick specific dates")
                            .font(.satoshi(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("From")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 20)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("To")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Show trip duration for manual dates
                        if tripDuration > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text("\(tripDuration) day\(tripDuration == 1 ? "" : "s") trip")
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
            } else {
                // Select and set dates
                selectedPreset = preset
                customDuration = 7 // Default duration
                updateDatesForPreset()
            }
        }
    }
    
    private func updateDatesForPreset() {
        guard let preset = selectedPreset else { return }
        let calendar = Calendar.current
        let now = Date()
        
        switch preset {
        case .nextMonth:
            // Start: Beginning of next month
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
               let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) {
                startDate = startOfMonth
                endDate = calendar.date(byAdding: .day, value: customDuration, to: startDate) ?? startDate
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
                endDate = calendar.date(byAdding: .day, value: customDuration, to: startDate) ?? startDate
            }
            
        case .flexible:
            // Start: 30 days from now
            startDate = calendar.date(byAdding: .day, value: 30, to: now) ?? now
            endDate = calendar.date(byAdding: .day, value: customDuration, to: startDate) ?? startDate
        }
    }
}

enum DatePreset {
    case nextMonth
    case thisSummer
    case flexible
}

struct PresetDateButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.satoshi(size: 18, weight: .medium))
                
                Spacer()
                
                // Always render checkmark, control visibility with opacity
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.5)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.9))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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

#Preview {
    CreateFirstPlanView()
        .environmentObject(AuthViewModel())
}

