//
//  AppIconView.swift
//  TravelPlanner
//
//  Run this View to generate your App Icon!
//  1. Preview this file
//  2. Screenshot the square
//  3. Upload to appicon.co to generate assets
//

import SwiftUI

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.5, blue: 1.0),
                    Color(red: 0.6, green: 0.3, blue: 0.9),
                    Color(red: 0.9, green: 0.4, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Icon
            Image(systemName: "airplane.departure")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
                .frame(width: 600, height: 600) // Large size for high res
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .frame(width: 1024, height: 1024) // Official App Store Icon Size
        .ignoresSafeArea()
    }
}

#Preview {
    AppIconView()
        .frame(width: 500, height: 500) // Smaller preview for Xcode
}


