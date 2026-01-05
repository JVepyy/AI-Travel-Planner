import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthenticationService {
    static let shared = AuthenticationService()
    
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let db = Firestore.firestore()
    
    private init() {}
    
    var currentUser: FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    func isLoggedIn() -> Bool {
        return Auth.auth().currentUser != nil
    }
    
    func saveUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData([
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "createdAt": user.createdAt
        ])
    }
    
    func getUser() async throws -> User? {
        guard let currentUser = Auth.auth().currentUser else {
            return nil
        }
        
        let doc = try await db.collection("users").document(currentUser.uid).getDocument()
        
        guard let data = doc.data() else {
            return nil
        }
        
        return User(
            id: data["id"] as? String ?? currentUser.uid,
            email: data["email"] as? String ?? currentUser.email ?? "",
            name: data["name"] as? String ?? "Traveler",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    func hasSeenOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
    }
    
    func setOnboardingSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
    }
    
    func logout() throws {
        try Auth.auth().signOut()
        UserDefaults.standard.removeObject(forKey: hasSeenOnboardingKey)
        GoogleSignInManager.shared.signOut()
    }
    
    func loginWithApple(credential: AuthCredential) async throws -> User {
        let result = try await Auth.auth().signIn(with: credential)
        
        let user = User(
            id: result.user.uid,
            email: result.user.email ?? "user@apple.com",
            name: result.user.displayName ?? "Traveler"
        )
        
        try await saveUser(user)
        
        return user
    }
    
    func loginWithGoogle(credential: AuthCredential) async throws -> User {
        let result = try await Auth.auth().signIn(with: credential)
        
        let user = User(
            id: result.user.uid,
            email: result.user.email ?? "user@gmail.com",
            name: result.user.displayName?.split(separator: " ").first.map(String.init) ?? "Traveler"
        )
        
        try await saveUser(user)
        
        return user
    }
}
