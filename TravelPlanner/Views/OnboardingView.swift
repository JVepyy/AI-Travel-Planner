import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentPage = 0
    @State private var userName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var buttonScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
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
                    HStack {
                        Spacer()
                        
                        if currentPage < onboardingPages.count - 1 && !(currentPage == 2 && isTextFieldFocused) {
                            Button(action: {
                                authViewModel.finishOnboarding()
                            }) {
                                Text("Skip")
                                    .font(.satoshi(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding()
                    .frame(height: 60)
                    
                    TabView(selection: $currentPage) {
                        ForEach(Array(onboardingPages.enumerated()), id: \.element.id) { index, page in
                            if index == 2 {
                                NameInputPageView(userName: $userName, isTextFieldFocused: _isTextFieldFocused)
                                    .tag(index)
                            } else {
                                OnboardingPageView(page: page, isActive: currentPage == index, isFirstPage: index == 0)
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onAppear {
                        userName = authViewModel.currentUser?.name ?? "Traveler"
                    }
                    .onChange(of: currentPage) { newPage in
                        if newPage != 2 {
                            isTextFieldFocused = false
                        }
                    }
                    
                    Spacer()
                }
                .ignoresSafeArea(.keyboard)
                
                VStack(spacing: 20) {
                    if currentPage == onboardingPages.count - 1 {
                        Button(action: {
                            saveUserName()
                            authViewModel.finishOnboarding()
                        }) {
                            ZStack {
                                Color.white
                                
                                Text("Continue")
                                    .font(.satoshi(size: 18, weight: .bold))
                                    .foregroundColor(.clear)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.3, green: 0.5, blue: 1.0),
                                                Color(red: 0.6, green: 0.3, blue: 0.9),
                                                Color(red: 0.9, green: 0.4, blue: 0.6)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .mask(
                                            Text("Continue")
                                                .font(.satoshi(size: 18, weight: .bold))
                                        )
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                        }
                        .scaleEffect(buttonScale)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                buttonScale = 1.03
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .shadow(color: currentPage == index ? .white : .clear, radius: 10, x: 0, y: 0)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentPage)
                        }
                    }
                    .padding(.bottom, 50)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard)
        }
    }
    
    private func saveUserName() {
        if !userName.isEmpty && userName != "Traveler" {
            if var user = authViewModel.currentUser {
                user.name = userName
                authViewModel.currentUser = user
                Task {
                    try? await AuthenticationService.shared.saveUser(user)
                }
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let isFirstPage: Bool
    @State private var iconScale: CGFloat = 0.9
    @State private var iconRotation: Double = 0
    @State private var iconOpacity: Double = 0
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)
            
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
                .opacity(iconOpacity)
                .onAppear {
                    if isActive {
                        if isFirstPage {
                            iconScale = 0.5
                            iconOpacity = 1
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                                iconScale = 1.0
                                iconRotation = 360
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.4)) {
                                iconScale = 1.0
                                iconOpacity = 1.0
                            }
                        }
                        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                            textOffset = 0
                            textOpacity = 1
                        }
                    }
                }
                .onChange(of: isActive) { active in
                    if active {
                        if isFirstPage {
                            iconScale = 0.5
                            iconRotation = 0
                            iconOpacity = 1
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                                iconScale = 1.0
                                iconRotation = 360
                            }
                        } else {
                            iconScale = 0.9
                            iconOpacity = 0
                            withAnimation(.easeOut(duration: 0.4)) {
                                iconScale = 1.0
                                iconOpacity = 1.0
                            }
                        }
                        textOffset = 50
                        textOpacity = 0
                        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                            textOffset = 0
                            textOpacity = 1
                        }
                    }
                }
            
            Spacer()
                .frame(height: 50)
            
            VStack(spacing: 24) {
                Text(page.title)
                    .font(.satoshi(size: 32, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                if !page.description.isEmpty {
                    Text(page.description)
                        .font(.lora(size: 20, italic: true))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                        .offset(y: textOffset)
                        .opacity(textOpacity)
                }
            }
            
            Spacer()
        }
    }
}

struct NameInputPageView: View {
    @Binding var userName: String
    @FocusState var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 120)
            
            VStack(spacing: 16) {
                Text("What's your name?")
                    .font(.satoshi(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("We'd love to personalize your experience")
                    .font(.lora(size: 18, italic: true))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            Spacer()
                .frame(height: 80)
            
            VStack(alignment: .center, spacing: 4) {
                TextField("", text: $userName)
                    .font(.satoshi(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .multilineTextAlignment(.center)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .onSubmit {
                        isTextFieldFocused = false
                    }
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
        .environmentObject(AuthViewModel())
}

