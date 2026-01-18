import SwiftUI

struct TravelPlanView: View {
    let plan: TravelPlan
    @Environment(\.dismiss) var dismiss
    @State private var animateHeader = false
    @State private var isItineraryRevealed = false
    @State private var buttonPulse = false
    
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
                    VStack(spacing: 32) {
                        // Celebratory Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                if let flag = plan.flagEmoji {
                                    Text(flag)
                                        .font(.system(size: 50))
                                } else {
                                    Image(systemName: "airplane.departure")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(animateHeader ? 1.0 : 0.8)
                            .opacity(animateHeader ? 1.0 : 0.0)
                            
                            VStack(spacing: 8) {
                                Text("Your Plan is Ready! ✈️")
                                    .font(.satoshi(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(animateHeader ? 1.0 : 0.0)
                                
                                Text(plan.formattedName)
                                    .font(.satoshi(size: 24, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .opacity(animateHeader ? 1.0 : 0.0)
                            }
                            
                            // Date and Budget Info Card
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text(formatDate(plan.startDate))
                                        .font(.satoshi(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Start")
                                        .font(.satoshi(size: 10, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                VStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text(formatDate(plan.endDate))
                                        .font(.satoshi(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("End")
                                        .font(.satoshi(size: 10, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                if let totalCost = plan.totalEstimatedCost {
                                    Divider()
                                        .frame(height: 40)
                                        .background(Color.white.opacity(0.3))
                                    
                                    VStack(spacing: 4) {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white.opacity(0.9))
                                        Text(totalCost)
                                            .font(.satoshi(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.9))
                                        Text("Budget")
                                            .font(.satoshi(size: 10, weight: .regular))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
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
                            .opacity(animateHeader ? 1.0 : 0.0)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        
                        // Highlights Section
                        if !plan.highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 20))
                                    Text("Highlights")
                                        .font(.satoshi(size: 24, weight: .bold))
                                }
                                .foregroundColor(.white)
                                
                                VStack(spacing: 12) {
                                    ForEach(Array(plan.highlights.enumerated()), id: \.offset) { index, highlight in
                                        HStack(spacing: 12) {
                                            // Gradient icon circle
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: index == 0 
                                                                ? [Color.yellow, Color.orange]
                                                                : [Color.pink, Color.purple]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 32, height: 32)
                                                
                                                Image(systemName: index == 0 ? "crown.fill" : "sparkle")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Text(highlight)
                                                .font(.satoshi(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: index == 0
                                                                    ? [Color.yellow.opacity(0.6), Color.orange.opacity(0.3)]
                                                                    : [Color.pink.opacity(0.5), Color.purple.opacity(0.3)]),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            ),
                                                            lineWidth: 1.5
                                                        )
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                        
                        // Unlock / Itinerary Section
                        if isItineraryRevealed {
                            // Day-by-day itinerary
                            VStack(alignment: .leading, spacing: 24) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 24))
                                    Text("Your Itinerary")
                                        .font(.satoshi(size: 28, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                
                                ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, day in
                                    EnhancedDayCard(day: day, index: index)
                                        .padding(.horizontal, 32)
                                }
                            }
                            .padding(.top, 8)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            
                            // Tips Section
                            if !plan.localTips.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    EnhancedTipsSection(title: "Local Tips", icon: "lightbulb.fill", tips: plan.localTips)
                                }
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            Spacer()
                                .frame(height: 50)
                        } else {
                            // Unlock Button
                            VStack(spacing: 16) {
                                // Unlock button with enhanced pulsing
                                Button(action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isItineraryRevealed = true
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.open.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                        Text("Reveal My Adventure")
                                            .font(.satoshi(size: 18, weight: .bold))
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 18))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(
                                        ZStack {
                                            // Outer glow
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(red: 1.0, green: 0.6, blue: 0.2),
                                                            Color(red: 1.0, green: 0.4, blue: 0.6)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .blur(radius: buttonPulse ? 20 : 10)
                                                .opacity(buttonPulse ? 0.9 : 0.4)
                                                .scaleEffect(buttonPulse ? 1.1 : 1.0)
                                            
                                            // Main button
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(red: 1.0, green: 0.5, blue: 0.2),
                                                            Color(red: 0.9, green: 0.3, blue: 0.5)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                            
                                            // Shimmer overlay
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0),
                                                            Color.white.opacity(buttonPulse ? 0.3 : 0.1),
                                                            Color.white.opacity(0)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        }
                                    )
                                    .scaleEffect(buttonPulse ? 1.03 : 1.0)
                                }
                                .padding(.horizontal, 32)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                        buttonPulse = true
                                    }
                                }
                                
                                // Preview hint
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 14))
                                    Text("Tap to unlock your journey")
                                        .font(.satoshi(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 50)
                        }
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
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateHeader = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct HighlightChip: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 12))
            Text(text)
                .font(.satoshi(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct EnhancedDayCard: View {
    let day: DayItinerary
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Day header with gradient
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text("\(day.dayNumber)")
                        .font(.satoshi(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let theme = day.theme {
                        Text(theme)
                            .font(.satoshi(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Day \(day.dayNumber)")
                            .font(.satoshi(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(formatDayDate(day.date))
                        .font(.satoshi(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if let cost = day.estimatedDailyCost {
                    Text(cost)
                        .font(.satoshi(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                        )
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Activities
            if !day.activities.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "map.fill")
                            .font(.system(size: 16))
                        Text("Activities")
                            .font(.satoshi(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    
                    ForEach(day.activities) { activity in
                        EnhancedActivityRow(activity: activity)
                    }
                }
            }
            
            // Restaurants
            if !day.restaurants.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                        Text("Restaurants")
                            .font(.satoshi(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    
                    ForEach(day.restaurants) { restaurant in
                        EnhancedRestaurantRow(restaurant: restaurant)
                    }
                }
            }
            
            // Hidden Gems
            if !day.hiddenGems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                        Text("Hidden Gems")
                            .font(.satoshi(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    
                    ForEach(day.hiddenGems, id: \.self) { gem in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 4)
                            Text(gem)
                                .font(.satoshi(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            
            // Tip
            if let tip = day.tip {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 2)
                    Text(tip)
                        .font(.satoshi(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private func formatDayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

struct EnhancedActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.time)
                    .font(.satoshi(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                if let duration = activity.duration {
                    Text(duration)
                        .font(.satoshi(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 70, alignment: .leading)
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.name)
                    .font(.satoshi(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Text(activity.description)
                    .font(.satoshi(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
                
                HStack(spacing: 12) {
                    if let location = activity.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(location)
                                .font(.satoshi(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let cost = activity.cost {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 12))
                            Text(cost)
                                .font(.satoshi(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct EnhancedRestaurantRow: View {
    let restaurant: Restaurant
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.time)
                    .font(.satoshi(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70, alignment: .leading)
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(.satoshi(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                if let cuisine = restaurant.cuisine {
                    Text(cuisine)
                        .font(.satoshi(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                HStack(spacing: 12) {
                    if let priceRange = restaurant.priceRange {
                        Text(priceRange)
                            .font(.satoshi(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let reservation = restaurant.reservation {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                            Text(reservation)
                                .font(.satoshi(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct EnhancedTipsSection: View {
    let title: String
    let icon: String
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.satoshi(size: 24, weight: .bold))
            }
            .foregroundColor(.white)
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 18))
                        .padding(.top, 2)
                    Text(tip)
                        .font(.satoshi(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

#Preview {
    TravelPlanView(plan: TravelPlan(
        userId: "test",
        destination: "Paris",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        budget: "moderate",
        days: []
    ))
}
