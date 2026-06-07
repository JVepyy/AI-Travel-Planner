import Foundation
import CoreLocation
import MapKit

@MainActor
final class GeocodingService {
    static let shared = GeocodingService()

    private var cache: [String: CLLocationCoordinate2D] = [:]
    private var inflight: [String: Task<CLLocationCoordinate2D?, Never>] = [:]

    /// Reject results farther than this from the destination — guards against
    /// MKLocalSearch returning a same-named place on another continent
    /// (e.g. a "Pizza" in the US when planning Budapest).
    private let maxDistanceFromCenter: CLLocationDistance = 250_000 // 250 km

    private init() {}

    func coordinate(
        for query: String,
        near hint: String? = nil,
        regionCenter: CLLocationCoordinate2D? = nil
    ) async -> CLLocationCoordinate2D? {
        let key = cacheKey(query: query, hint: hint)
        if let cached = cache[key] { return cached }

        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task<CLLocationCoordinate2D?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.performLookup(query: query, hint: hint, regionCenter: regionCenter)
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        if let result {
            cache[key] = result
        }
        return result
    }

    /// Invalidates a cached coordinate so the next lookup re-geocodes (used after a swap).
    func invalidate(query: String, near hint: String? = nil) {
        cache[cacheKey(query: query, hint: hint)] = nil
    }

    private func performLookup(
        query: String,
        hint: String?,
        regionCenter: CLLocationCoordinate2D?
    ) async -> CLLocationCoordinate2D? {
        let primary = hint.map { "\(query), \($0)" } ?? query
        if let coord = await searchMap(query: primary, regionCenter: regionCenter) { return coord }
        if hint != nil, let coord = await searchMap(query: query, regionCenter: regionCenter) { return coord }
        return nil
    }

    private func searchMap(query: String, regionCenter: CLLocationCoordinate2D?) async -> CLLocationCoordinate2D? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let center = regionCenter {
            // Bias results to the destination city (~60 km box).
            request.region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
            )
        }

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            let coords = response.mapItems.map { $0.placemark.coordinate }
            guard !coords.isEmpty else { return nil }

            guard let center = regionCenter else { return coords.first }

            // Pick the result closest to the destination and discard absurd ones.
            let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let best = coords.min { lhs, rhs in
                CLLocation(latitude: lhs.latitude, longitude: lhs.longitude).distance(from: centerLoc)
                    < CLLocation(latitude: rhs.latitude, longitude: rhs.longitude).distance(from: centerLoc)
            }
            guard let best else { return nil }
            let distance = CLLocation(latitude: best.latitude, longitude: best.longitude).distance(from: centerLoc)
            return distance <= maxDistanceFromCenter ? best : nil
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
