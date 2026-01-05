import Foundation
import GoogleSignIn
import UIKit
import FirebaseAuth

class GoogleSignInManager {
    static let shared = GoogleSignInManager()
    
    private let clientID = "971881498254-jkiiofcslk70sqjkqumd99brbtmg4f90.apps.googleusercontent.com"
    
    private init() {}
    
    func signIn() async throws -> AuthCredential {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let signInResult = signInResult else {
                    continuation.resume(throwing: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No sign in result"]))
                    return
                }
                
                guard let idToken = signInResult.user.idToken?.tokenString else {
                    continuation.resume(throwing: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token"]))
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: signInResult.user.accessToken.tokenString
                )
                
                continuation.resume(returning: credential)
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

