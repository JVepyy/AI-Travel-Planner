import Foundation
import FirebaseFirestore
import FirebaseFunctions

class TravelPlanService {
    static let shared = TravelPlanService()
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")
    
    private init() {}
    
    func generatePlan(data: PlanRequestData) async throws -> TravelPlan {
        print("=== GENERATE PLAN START ===")
        let generatePlanFunction = functions.httpsCallable("generateTravelPlan")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var requestData: [String: Any] = [
            "destination": data.destination,
            "startDate": formatter.string(from: data.startDate),
            "endDate": formatter.string(from: data.endDate),
            "budget": data.budget,
            "isFlexibleDates": data.isFlexibleDates,
            "duration": data.duration
        ]
        
        if let specialRequests = data.specialRequests {
            requestData["specialRequests"] = specialRequests
        }
        
        print("Calling Cloud Function with data: \(requestData)")
        
        let result = try await generatePlanFunction.call(requestData)
        
        print("=== CLOUD FUNCTION RESPONSE ===")
        print("Raw result.data: \(String(describing: result.data))")
        
        guard let responseData = result.data as? [String: Any],
              let planData = responseData["plan"] as? [String: Any] else {
            print("ERROR: Invalid response structure")
            throw NSError(domain: "TravelPlanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        
        print("Plan data userId: \(planData["userId"] ?? "NIL")")
        print("Plan data id: \(planData["id"] ?? "NIL")")
        
        let plan = try parsePlan(from: planData)
        print("=== PARSED PLAN ===")
        print("Plan.id: \(plan.id)")
        print("Plan.userId: \(plan.userId)")
        print("Plan.destination: \(plan.destination)")
        
        return plan
    }
    
    func savePlan(_ plan: TravelPlan) async throws {
        var data: [String: Any] = [
            "id": plan.id,
            "userId": plan.userId,
            "destination": plan.destination,
            "startDate": Timestamp(date: plan.startDate),
            "endDate": Timestamp(date: plan.endDate),
            "budget": plan.budget,
            "createdAt": Timestamp(date: plan.createdAt),
            "updatedAt": Timestamp(date: plan.updatedAt)
        ]
        
        if let displayName = plan.displayName {
            data["displayName"] = displayName
        }
        
        if let countryCode = plan.countryCode {
            data["countryCode"] = countryCode
        }
        
        if let specialRequests = plan.specialRequests {
            data["specialRequests"] = specialRequests
        }
        
        if let totalCost = plan.totalEstimatedCost {
            data["totalEstimatedCost"] = totalCost
        }
        
        data["highlights"] = plan.highlights
        data["localTips"] = plan.localTips
        
        // Encode days
        data["days"] = plan.days.map { day in
            var dayData: [String: Any] = [
                "id": day.id,
                "dayNumber": day.dayNumber,
                "date": Timestamp(date: day.date)
            ]
            
            if let theme = day.theme {
                dayData["theme"] = theme
            }
            
            if let dailyCost = day.estimatedDailyCost {
                dayData["estimatedDailyCost"] = dailyCost
            }
            
            dayData["activities"] = day.activities.map { activity in
                var activityData: [String: Any] = [
                    "id": activity.id,
                    "time": activity.time,
                    "name": activity.name,
                    "description": activity.description
                ]
                if let duration = activity.duration { activityData["duration"] = duration }
                if let cost = activity.cost { activityData["cost"] = cost }
                if let location = activity.location { activityData["location"] = location }
                if let tips = activity.tips { activityData["tips"] = tips }
                return activityData
            }
            
            dayData["restaurants"] = day.restaurants.map { restaurant in
                var restaurantData: [String: Any] = [
                    "id": restaurant.id,
                    "name": restaurant.name,
                    "time": restaurant.time
                ]
                if let cuisine = restaurant.cuisine { restaurantData["cuisine"] = cuisine }
                if let priceRange = restaurant.priceRange { restaurantData["priceRange"] = priceRange }
                if let reservation = restaurant.reservation { restaurantData["reservation"] = reservation }
                if let description = restaurant.description { restaurantData["description"] = description }
                return restaurantData
            }
            
            dayData["hiddenGems"] = day.hiddenGems
            if let tip = day.tip {
                dayData["tip"] = tip
            }
            
            return dayData
        }
        
        try await db.collection("travelPlans").document(plan.id).setData(data)
    }
    
    func getPlan(planId: String) async throws -> TravelPlan? {
        let doc = try await db.collection("travelPlans").document(planId).getDocument()
        
        guard let data = doc.data() else {
            return nil
        }
        
        return try parsePlan(from: data)
    }
    
    func getUserPlans(userId: String) async throws -> [TravelPlan] {
        print("Fetching plans for userId: \(userId)")
        
        let snapshot = try await db.collection("travelPlans")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        print("Found \(snapshot.documents.count) documents")
        
        let plans = snapshot.documents.compactMap { doc -> TravelPlan? in
            do {
                return try parsePlan(from: doc.data())
            } catch {
                print("Error parsing plan: \(error)")
                return nil
            }
        }
        
        // Sort by createdAt descending in memory
        return plans.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func parsePlan(from data: [String: Any]) throws -> TravelPlan {
        // This is a simplified parser - in production, you'd want more robust error handling
        let id = data["id"] as? String ?? UUID().uuidString
        let userId = data["userId"] as? String ?? ""
        let destination = data["destination"] as? String ?? ""
        let displayName = data["displayName"] as? String
        let countryCode = data["countryCode"] as? String
        let startDate = parseDate(from: data["startDate"]) ?? Date()
        let endDate = parseDate(from: data["endDate"]) ?? Date()
        let budget = data["budget"] as? String ?? "moderate"
        let specialRequests = data["specialRequests"] as? String
        let totalEstimatedCost = data["totalEstimatedCost"] as? String
        let highlights = data["highlights"] as? [String] ?? []
        let localTips = data["localTips"] as? [String] ?? []
        let createdAt = parseDate(from: data["createdAt"]) ?? Date()
        let updatedAt = parseDate(from: data["updatedAt"]) ?? Date()
        
        let daysData = data["days"] as? [[String: Any]] ?? []
        let days = try daysData.map { try parseDay(from: $0) }
        
        return TravelPlan(
            id: id,
            userId: userId,
            destination: destination,
            displayName: displayName,
            countryCode: countryCode,
            startDate: startDate,
            endDate: endDate,
            budget: budget,
            specialRequests: specialRequests,
            days: days,
            totalEstimatedCost: totalEstimatedCost,
            highlights: highlights,
            localTips: localTips,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func parseDay(from data: [String: Any]) throws -> DayItinerary {
        let id = data["id"] as? String ?? UUID().uuidString
        let dayNumber = data["dayNumber"] as? Int ?? 1
        let date = parseDate(from: data["date"]) ?? Date()
        let theme = data["theme"] as? String
        let estimatedDailyCost = data["estimatedDailyCost"] as? String
        
        let activitiesData = data["activities"] as? [[String: Any]] ?? []
        let activities = activitiesData.map { parseActivity(from: $0) }
        
        let restaurantsData = data["restaurants"] as? [[String: Any]] ?? []
        let restaurants = restaurantsData.map { parseRestaurant(from: $0) }
        
        let hiddenGems = data["hiddenGems"] as? [String] ?? []
        let tip = data["tip"] as? String
        
        return DayItinerary(
            id: id,
            dayNumber: dayNumber,
            date: date,
            theme: theme,
            activities: activities,
            restaurants: restaurants,
            hiddenGems: hiddenGems,
            tip: tip,
            estimatedDailyCost: estimatedDailyCost
        )
    }
    
    private func parseActivity(from data: [String: Any]) -> Activity {
        Activity(
            id: data["id"] as? String ?? UUID().uuidString,
            time: data["time"] as? String ?? "",
            name: data["name"] as? String ?? "",
            description: data["description"] as? String ?? "",
            duration: data["duration"] as? String,
            cost: data["cost"] as? String,
            location: data["location"] as? String,
            tips: data["tips"] as? String
        )
    }
    
    private func parseRestaurant(from data: [String: Any]) -> Restaurant {
        Restaurant(
            id: data["id"] as? String ?? UUID().uuidString,
            name: data["name"] as? String ?? "",
            cuisine: data["cuisine"] as? String,
            priceRange: data["priceRange"] as? String,
            time: data["time"] as? String ?? "",
            reservation: data["reservation"] as? String,
            description: data["description"] as? String
        )
    }
    
    func deletePlan(planId: String) async throws {
        try await db.collection("travelPlans").document(planId).delete()
    }
    
    // Helper function to parse dates from various formats
    private func parseDate(from value: Any?) -> Date? {
        guard let value = value else { return nil }
        
        // If it's already a Timestamp
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        
        // If it's a String (ISO8601 format from Cloud Function)
        if let dateString = value as? String {
            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try basic date format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // Try full ISO format
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        // If it's a Double (Unix timestamp)
        if let timestamp = value as? Double {
            return Date(timeIntervalSince1970: timestamp / 1000) // Convert from milliseconds
        }
        
        // If it's an Int (Unix timestamp)
        if let timestamp = value as? Int {
            return Date(timeIntervalSince1970: Double(timestamp) / 1000)
        }
        
        return nil
    }
}

