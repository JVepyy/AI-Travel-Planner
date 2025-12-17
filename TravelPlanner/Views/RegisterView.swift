import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                                .padding(.top, 40)
                            
                            Text("Create Account")
                                .font(.satoshi(size: 28, weight: .bold))
                            
                            Text("Start planning your adventures")
                                .font(.satoshi(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(.plain)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                SecureField("Create a password", text: $password)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.satoshi(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.satoshi(size: 14, weight: .regular))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match")
                                .font(.satoshi(size: 14, weight: .regular))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.register(email: email, password: password, name: name)
                                if viewModel.isAuthenticated {
                                    dismiss()
                                }
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            } else {
                                Text("Create Account")
                                    .font(.satoshi(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            }
                        }
                        .background(Color.blue)
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .disabled(viewModel.isLoading || name.isEmpty || email.isEmpty || password.isEmpty || password != confirmPassword)
                        .opacity((viewModel.isLoading || name.isEmpty || email.isEmpty || password.isEmpty || password != confirmPassword) ? 0.6 : 1.0)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}
