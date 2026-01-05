import SwiftUI
import AuthenticationServices
import Combine
import FirebaseAuth

class AppleSignInManager: NSObject, ObservableObject {
    static let shared = AppleSignInManager()
    
    @Published var isAuthenticated = false
    
    private override init() {
        super.init()
    }
    
    func signIn() async throws -> AuthCredential {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = SignInDelegate(continuation: continuation)
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            authorizationController.performRequests()
            
            objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

class SignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let continuation: CheckedContinuation<AuthCredential, Error>
    
    init(continuation: CheckedContinuation<AuthCredential, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                continuation.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"]))
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nil,
                fullName: appleIDCredential.fullName
            )
            
            continuation.resume(returning: credential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

