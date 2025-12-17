//
//  AppIconGenerator.swift
//  TravelPlanner
//
//  Helper view to generate app icon
//  Run this view, screenshot it, and use as app icon
//

import SwiftUI

struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // Same gradient as onboarding
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.5, blue: 1.0),
                    Color(red: 0.6, green: 0.3, blue: 0.9),
                    Color(red: 0.9, green: 0.4, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // White plane icon
            Image(systemName: "airplane.departure")
                .font(.system(size: 500, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    AppIconGenerator()
}


