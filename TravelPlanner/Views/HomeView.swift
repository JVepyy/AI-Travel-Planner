import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back,")
                        .font(.satoshi(size: 20, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.currentUser?.name ?? "Traveler")
                        .font(.satoshi(size: 32, weight: .bold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
                
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        Text("Ready for your next adventure?")
                            .font(.satoshi(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Let AI create your perfect travel plan")
                            .font(.satoshi(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                    }) {
                        Text("Create Travel Plan")
                            .font(.satoshi(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.3, green: 0.5, blue: 1.0),
                                        Color(red: 0.6, green: 0.3, blue: 0.9)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                    }) {
                        Label("Profile", systemImage: "person.circle")
                    }
                    
                    Button(action: {
                    }) {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        viewModel.logout()
                    }) {
                        Label("Log Out", systemImage: "arrow.right.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
