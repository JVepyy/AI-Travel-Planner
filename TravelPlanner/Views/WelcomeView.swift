import SwiftUI

struct WelcomeView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isLoading = false
    
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
                Spacer()
                
                Image(systemName: "airplane.departure")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                Text("Get Started")
                    .font(.satoshi(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 24)
                
                VStack(spacing: 8) {
                    Text("Start planning your dream trip for free.")
                        .font(.satoshi(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Join the community of smart travelers.")
                        .font(.satoshi(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Button(action: {
                            handleAppleSignIn()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Continue with Apple")
                                    .font(.satoshi(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(white: 0.15))
                            .cornerRadius(26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                            )
                            .shadow(color: Color.white.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .disabled(isLoading)
                        
                        Button(action: {
                            handleGoogleSignIn()
                        }) {
                            HStack(spacing: 10) {
                                Image("google-logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .font(.satoshi(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(26)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    } else {
                        Text("By tapping continue you agree to our **Terms**\nand **Privacy Policy**")
                            .font(.satoshi(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .cornerRadius(36, corners: [.topLeft, .topRight])
                .edgesIgnoringSafeArea(.bottom)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    private func handleAppleSignIn() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await viewModel.login(email: "apple@user.com", password: "dummy")
            isLoading = false
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await viewModel.login(email: "google@user.com", password: "dummy")
            isLoading = false
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    WelcomeView()
}
