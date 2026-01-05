import Foundation

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        icon: "airplane.departure",
        title: "Hi, I'm Travel Planner, your new travel friend!",
        description: "Let's create your perfect journey together."
    ),
    OnboardingPage(
        icon: "lock.fill",
        title: "Your travel plans are private and only you have access to them.",
        description: ""
    ),
    OnboardingPage(
        icon: "person.fill",
        title: "What's your name?",
        description: "We'd love to personalize your experience"
    ),
    OnboardingPage(
        icon: "globe.americas.fill",
        title: "Ready to explore the world with me?",
        description: "Your next adventure awaits!"
    )
]

