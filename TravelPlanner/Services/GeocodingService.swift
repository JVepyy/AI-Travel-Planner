import Foundation
import CoreLocation
import MapKit

@MainActor
final class GeocodingService {
    static let shared = GeocodingService()

    private var cache: [String: CLLocationCoordinate2D] = [:]
    private var inflight: [String: Task<CLLocationCoordinate2D?, Never>] = [:]

    private init() {}

    func coordinate(for query: String, near hint: String? = nil) async -> CLLocationCoordinate2D? {
        let key = cacheKey(query: query, hint: hint)
        if let cached = cache[key] { return cached }

        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task<CLLocationCoordinate2D?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.performLookup(query: query, hint: hint)
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        if let result {
            cache[key] = result
        }
        return result
    }

    private func performLookup(query: String, hint: String?) async -> CLLocationCoordinate2D? {
        let primary = hint.map { "\(query), \($0)" } ?? query
        if let coord = await searchMap(query: primary) { return coord }
        if hint != nil, let coord = await searchMap(query: query) { return coord }
        return nil
    }

    private func searchMap(query: String) async -> CLLocationCoordinate2D? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }

    private func cacheKey(query: String, hint: String?) -> String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let h = hint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return "\(q)|\(h)"
    }
}
