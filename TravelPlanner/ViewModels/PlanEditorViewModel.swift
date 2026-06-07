//
//  PlanEditorViewModel.swift
//  TravelPlanner
//
//  Holds an editable copy of a TravelPlan and persists edits (delete, update,
//  reorder) to Firestore with silent, debounced autosave.
//

import Foundation
import Combine

@MainActor
final class PlanEditorViewModel: ObservableObject {
    @Published var plan: TravelPlan

    /// Called after every mutation so parent views (e.g. the Home list) can
    /// stay in sync with the edited plan.
    private let onChange: (TravelPlan) -> Void
    private let service = TravelPlanService.shared
    private var saveTask: Task<Void, Never>?

    init(plan: TravelPlan, onChange: @escaping (TravelPlan) -> Void = { _ in }) {
        self.plan = plan
        self.onChange = onChange
    }

    // MARK: - Undo support

    /// Captures a removed stop so it can be restored via `restore(_:)`.
    struct DeletedStop {
        let dayId: String
        let activity: Activity?
        let restaurant: Restaurant?
    }

    // MARK: - Mutations

    /// Deletes the activity/restaurant backing `stopId` ("act-…" / "res-…").
    /// Returns a token for Undo, or nil if not found.
    @discardableResult
    func deleteStop(stopId: String, dayId: String) -> DeletedStop? {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }) else { return nil }

        if let rawId = rawId(from: stopId, prefix: "act-") {
            guard let i = plan.days[dayIndex].activities.firstIndex(where: { $0.id == rawId }) else { return nil }
            let removed = plan.days[dayIndex].activities.remove(at: i)
            commit()
            return DeletedStop(dayId: dayId, activity: removed, restaurant: nil)
        }

        if let rawId = rawId(from: stopId, prefix: "res-") {
            guard let i = plan.days[dayIndex].restaurants.firstIndex(where: { $0.id == rawId }) else { return nil }
            let removed = plan.days[dayIndex].restaurants.remove(at: i)
            commit()
            return DeletedStop(dayId: dayId, activity: nil, restaurant: removed)
        }

        return nil
    }

    /// Re-inserts a previously deleted stop. Its stored `order` keeps it in place.
    func restore(_ deleted: DeletedStop) {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == deleted.dayId }) else { return }
        if let activity = deleted.activity {
            plan.days[dayIndex].activities.append(activity)
        } else if let restaurant = deleted.restaurant {
            plan.days[dayIndex].restaurants.append(restaurant)
        }
        commit()
    }

    func updateActivity(_ activity: Activity, dayId: String) {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }),
              let i = plan.days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) else { return }
        plan.days[dayIndex].activities[i] = activity
        commit()
    }

    func updateRestaurant(_ restaurant: Restaurant, dayId: String) {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }),
              let i = plan.days[dayIndex].restaurants.firstIndex(where: { $0.id == restaurant.id }) else { return }
        plan.days[dayIndex].restaurants[i] = restaurant
        commit()
    }

    /// Phase 2: applies a new full ordering of stop ids ("act-…"/"res-…") for a day.
    func reorderStops(orderedStopIds: [String], dayId: String) {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }) else { return }
        for (index, stopId) in orderedStopIds.enumerated() {
            if let rawId = rawId(from: stopId, prefix: "act-"),
               let i = plan.days[dayIndex].activities.firstIndex(where: { $0.id == rawId }) {
                plan.days[dayIndex].activities[i].order = index
            } else if let rawId = rawId(from: stopId, prefix: "res-"),
                      let i = plan.days[dayIndex].restaurants.firstIndex(where: { $0.id == rawId }) {
                plan.days[dayIndex].restaurants[i].order = index
            }
        }
        commit()
    }

    // MARK: - Helpers

    private func rawId(from stopId: String, prefix: String) -> String? {
        guard stopId.hasPrefix(prefix) else { return nil }
        return String(stopId.dropFirst(prefix.count))
    }

    private func commit() {
        plan.updatedAt = Date()
        onChange(plan)
        scheduleSave()
    }

    /// Debounced autosave: rapid edits coalesce into a single Firestore write.
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = plan
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            guard !Task.isCancelled else { return }
            do {
                try await self?.service.savePlan(snapshot)
            } catch {
                print("Autosave failed: \(error)")
            }
        }
    }
}
