import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - Unified Stop Model

private enum StopKind: Hashable {
    case activity
    case restaurant
}

private struct Stop: Identifiable, Hashable {
    let id: String
    let kind: StopKind
    let title: String
    let subtitle: String?
    let time: String
    let description: String
    let cost: String?
    let location: String?
    let order: Int
}

private extension DayItinerary {
    var stops: [Stop] {
        let activityStops = activities.map { a in
            (sortOrder: a.order,
             stop: Stop(
                id: "act-\(a.id)",
                kind: .activity,
                title: a.name,
                subtitle: a.duration,
                time: a.time,
                description: a.description,
                cost: a.cost,
                location: a.location,
                order: 0
             ))
        }
        let restaurantStops = restaurants.map { r in
            (sortOrder: r.order,
             stop: Stop(
                id: "res-\(r.id)",
                kind: .restaurant,
                title: r.name,
                subtitle: r.cuisine,
                time: r.time,
                description: r.description ?? (r.cuisine ?? ""),
                cost: r.priceRange,
                location: r.location,
                order: 0
             ))
        }
        let combined = activityStops + restaurantStops
        // Sort by the stored explicit order; ties broken by time so freshly
        // generated plans (all order 0) still appear chronologically.
        let sorted = combined.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return TimeOrdering.sortKey(for: lhs.stop.time) < TimeOrdering.sortKey(for: rhs.stop.time)
        }
        return sorted.enumerated().map { index, item in
            Stop(
                id: item.stop.id,
                kind: item.stop.kind,
                title: item.stop.title,
                subtitle: item.stop.subtitle,
                time: item.stop.time,
                description: item.stop.description,
                cost: item.stop.cost,
                location: item.stop.location,
                order: index + 1
            )
        }
    }
}

// MARK: - Map Itinerary View

struct MapItineraryView: View {
    @ObservedObject var editor: PlanEditorViewModel
    @Environment(\.dismiss) private var dismiss

    private var plan: TravelPlan { editor.plan }

    @State private var selectedDayIndex: Int = 0
    @State private var selectedStopId: String?
    @State private var coordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var mapStyle: MapStyleKind = .standard
    @State private var showSheet = true

    private enum MapStyleKind: String, CaseIterable {
        case standard, imagery
        var icon: String {
            switch self {
            case .standard: return "map"
            case .imagery: return "globe.americas.fill"
            }
        }
    }

    private var currentDay: DayItinerary? {
        guard !plan.days.isEmpty else { return nil }
        return plan.days[min(selectedDayIndex, plan.days.count - 1)]
    }

    private var currentStops: [Stop] { currentDay?.stops ?? [] }

    private var currentDayCoordinatePairs: [(stop: Stop, coordinate: CLLocationCoordinate2D)] {
        currentStops.compactMap { stop in
            if let coord = coordinates[stop.id] { return (stop, coord) }
            return nil
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
                .ignoresSafeArea()

            topHeader
                .padding(.horizontal, 16)
                .padding(.top, 8)

            VStack {
                Spacer()
                mapStyleControl
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .sheet(isPresented: $showSheet) {
            ItinerarySheet(
                editor: editor,
                selectedDayIndex: $selectedDayIndex,
                selectedStopId: $selectedStopId,
                coordinates: coordinates,
                onStopTap: focusStop,
                onOpenInMaps: openInMaps,
                onActivitySwapped: { stopId, query in
                    Task { await regeocodeStop(stopId: stopId, query: query) }
                }
            )
            .presentationDetents([.height(120), .medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationCornerRadius(28)
            .interactiveDismissDisabled()
        }
        .task {
            await prepareCoordinates()
        }
        .onChange(of: selectedDayIndex) { _, _ in
            selectedStopId = nil
            zoomToCurrentDay()
        }
    }

    // MARK: Map Layer

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $cameraPosition, selection: $selectedStopId) {
            ForEach(plan.days.indices, id: \.self) { dayIdx in
                let day = plan.days[dayIdx]
                let stops = day.stops
                if dayIdx == selectedDayIndex {
                    let pairs: [(Stop, CLLocationCoordinate2D)] = stops.compactMap { stop in
                        guard let coord = coordinates[stop.id] else { return nil }
                        return (stop, coord)
                    }
                    if pairs.count >= 2 {
                        MapPolyline(coordinates: pairs.map { $0.1 })
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.9, green: 0.4, blue: 0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 6])
                            )
                    }
                    ForEach(pairs, id: \.0.id) { pair in
                        Annotation(pair.0.title, coordinate: pair.1, anchor: .bottom) {
                            MapPinView(stop: pair.0, isSelected: selectedStopId == pair.0.id)
                                .onTapGesture { focusStop(pair.0) }
                        }
                        .tag(pair.0.id)
                    }
                }
            }
        }
        .mapStyle(mapStyle == .standard ? .standard(elevation: .realistic) : .hybrid(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: Top Header

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let flag = plan.flagEmoji {
                        Text(flag).font(.system(size: 18))
                    }
                    Text(plan.formattedName)
                        .font(.satoshi(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text(headerDateRange)
                    .font(.satoshi(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer(minLength: 0)

            if let cost = plan.totalEstimatedCost {
                Text(cost)
                    .font(.satoshi(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var mapStyleControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mapStyle = mapStyle == .standard ? .imagery : .standard
            }
        } label: {
            Image(systemName: mapStyle.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var headerDateRange: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: plan.startDate)) → \(f.string(from: plan.endDate)) · \(plan.days.count) days"
    }

    // MARK: Camera + Geocoding

    private func prepareCoordinates() async {
        let geocoder = GeocodingService.shared
        let destinationHint = plan.formattedName
        let dest = await geocoder.coordinate(for: destinationHint)
        await MainActor.run {
            destinationCoordinate = dest
            if let dest, currentDayCoordinatePairs.isEmpty {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: dest,
                        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    )
                )
            }
        }

        for day in plan.days {
            for stop in day.stops {
                let query = stop.location ?? stop.title
                if let coord = await geocoder.coordinate(for: query, near: destinationHint, regionCenter: dest) {
                    await MainActor.run {
                        coordinates[stop.id] = coord
                    }
                }
            }
            if day.dayNumber == (currentDay?.dayNumber ?? -1) {
                await MainActor.run { zoomToCurrentDay() }
            }
        }
        await MainActor.run { zoomToCurrentDay() }
    }

    /// Re-geocodes a single stop after its location changed (e.g. an AI swap) and
    /// moves the camera to the new spot.
    private func regeocodeStop(stopId: String, query: String) async {
        let geocoder = GeocodingService.shared
        let destinationHint = plan.formattedName
        geocoder.invalidate(query: query, near: destinationHint)
        if let coord = await geocoder.coordinate(for: query, near: destinationHint, regionCenter: destinationCoordinate) {
            await MainActor.run {
                coordinates[stopId] = coord
                withAnimation(.easeInOut(duration: 0.4)) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        } else {
            // Couldn't locate the new place — drop the stale pin rather than mislead.
            await MainActor.run { coordinates[stopId] = nil }
        }
    }

    private func focusStop(_ stop: Stop) {
        selectedStopId = stop.id
        guard let coord = coordinates[stop.id] else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
            sheetDetent = .height(120)
        }
    }

    private func zoomToCurrentDay() {
        let coords = currentDayCoordinatePairs.map { $0.coordinate }
        if coords.isEmpty {
            if let dest = destinationCoordinate {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: dest,
                        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    )
                )
            }
            return
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.01)
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func openInMaps(_ stop: Stop) {
        guard let coord = coordinates[stop.id] else { return }
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = stop.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: NSNumber(value: MKMapType.standard.rawValue)
        ])
    }
}

// MARK: - Map Pin

private struct MapPinView: View {
    let stop: Stop
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)

                VStack(spacing: 0) {
                    Image(systemName: stop.kind == .activity ? "star.fill" : "fork.knife")
                        .font(.system(size: isSelected ? 12 : 10, weight: .bold))
                    Text("\(stop.order)")
                        .font(.system(size: isSelected ? 12 : 10, weight: .heavy))
                }
                .foregroundStyle(.white)
            }
            Triangle()
                .fill(gradient)
                .frame(width: 10, height: 8)
                .offset(y: -2)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var gradient: LinearGradient {
        switch stop.kind {
        case .activity:
            return LinearGradient(
                colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.6, green: 0.3, blue: 0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .restaurant:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 0.9, green: 0.3, blue: 0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Bottom Sheet

private struct ItinerarySheet: View {
    @ObservedObject var editor: PlanEditorViewModel
    @Binding var selectedDayIndex: Int
    @Binding var selectedStopId: String?
    let coordinates: [String: CLLocationCoordinate2D]
    let onStopTap: (Stop) -> Void
    let onOpenInMaps: (Stop) -> Void
    let onActivitySwapped: (_ stopId: String, _ query: String) -> Void

    @State private var pendingUndo: PlanEditorViewModel.DeletedStop?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var editMode: EditMode = .inactive
    @State private var swapTarget: SwapTarget?

    /// Identifies the activity being swapped (raw activity id + its day).
    private struct SwapTarget: Identifiable {
        let id: String       // raw activity id
        let dayId: String
    }

    private var plan: TravelPlan { editor.plan }

    private var currentDay: DayItinerary? {
        guard !plan.days.isEmpty else { return nil }
        return plan.days[min(selectedDayIndex, plan.days.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            daySelector
                .padding(.top, 8)

            ScrollViewReader { proxy in
                List {
                    if let day = currentDay {
                        dayHeader(day)
                            .plainRow()

                        Section {
                            ForEach(day.stops, id: \.id) { stop in
                                StopCard(
                                    stop: stop,
                                    isSelected: selectedStopId == stop.id,
                                    hasCoordinate: coordinates[stop.id] != nil,
                                    onTap: { onStopTap(stop) },
                                    onOpenInMaps: { onOpenInMaps(stop) },
                                    onDelete: { deleteStop(stop) },
                                    onSwap: stop.kind == .activity ? { beginSwap(stop, dayId: day.id) } : nil
                                )
                                .id(stop.id)
                                .plainRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteStop(stop)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onMove { indices, newOffset in
                                moveStops(in: day, from: indices, to: newOffset)
                            }
                        } header: {
                            timelineHeader(day)
                        }

                        if !day.hiddenGems.isEmpty {
                            hiddenGemsSection(day.hiddenGems)
                                .plainRow()
                        }
                        if let tip = day.tip {
                            tipCard(tip)
                                .plainRow()
                        }
                    }

                    if !plan.highlights.isEmpty {
                        highlightsSection
                            .plainRow()
                    }
                    if !plan.localTips.isEmpty {
                        localTipsSection
                            .plainRow()
                    }

                    Color.clear
                        .frame(height: 24)
                        .plainRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
                .environment(\.editMode, $editMode)
                .onChange(of: selectedStopId) { _, newId in
                    if let id = newId {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let undo = pendingUndo {
                undoSnackbar(undo)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $swapTarget) { target in
            SwapSheet(
                editor: editor,
                dayId: target.dayId,
                activityId: target.id,
                onApplied: onActivitySwapped
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Edit / delete actions

    private func beginSwap(_ stop: Stop, dayId: String) {
        guard stop.id.hasPrefix("act-") else { return }
        let rawId = String(stop.id.dropFirst(4))
        swapTarget = SwapTarget(id: rawId, dayId: dayId)
    }

    /// Applies a drag-reorder to the merged stop list and persists the new order.
    private func moveStops(in day: DayItinerary, from indices: IndexSet, to newOffset: Int) {
        var ids = day.stops.map { $0.id }
        ids.move(fromOffsets: indices, toOffset: newOffset)
        editor.reorderStops(orderedStopIds: ids, dayId: day.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteStop(_ stop: Stop) {
        guard let dayId = currentDay?.id else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let deleted = editor.deleteStop(stopId: stop.id, dayId: dayId)
        if selectedStopId == stop.id { selectedStopId = nil }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            pendingUndo = deleted
        }
        scheduleUndoDismiss()
    }

    private func scheduleUndoDismiss() {
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4s
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) { pendingUndo = nil }
            }
        }
    }

    private func undoSnackbar(_ deleted: PlanEditorViewModel.DeletedStop) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("Removed")
                .font(.satoshi(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button {
                undoDismissTask?.cancel()
                editor.restore(deleted)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.25)) { pendingUndo = nil }
            } label: {
                Text("Undo")
                    .font(.satoshi(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.85))
        )
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    // MARK: Day selector

    private var daySelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, day in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selectedDayIndex = index
                                proxy.scrollTo(day.id, anchor: .center)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Day \(day.dayNumber)")
                                    .font(.satoshi(size: 13, weight: .bold))
                                if let theme = day.theme, !theme.isEmpty {
                                    Text(theme)
                                        .font(.satoshi(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .opacity(0.85)
                                }
                            }
                            .foregroundStyle(index == selectedDayIndex ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if index == selectedDayIndex {
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.3, green: 0.5, blue: 1.0),
                                                Color(red: 0.6, green: 0.3, blue: 0.9),
                                                Color(red: 0.9, green: 0.4, blue: 0.6)
                                            ],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                } else {
                                    Capsule().fill(Color.primary.opacity(0.06))
                                }
                            }
                        }
                        .id(day.id)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: Day header

    private func dayHeader(_ day: DayItinerary) -> some View {
        let stops = day.stops
        let activitiesCount = stops.filter { $0.kind == .activity }.count
        let restaurantsCount = stops.filter { $0.kind == .restaurant }.count

        return HStack(spacing: 14) {
            statTile(icon: "star.fill", value: "\(activitiesCount)", label: "Activities", colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.6, green: 0.3, blue: 0.9)])
            statTile(icon: "fork.knife", value: "\(restaurantsCount)", label: "Restaurants", colors: [Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 0.9, green: 0.3, blue: 0.5)])
            if let cost = day.estimatedDailyCost {
                statTile(icon: "creditcard.fill", value: cost, label: "Day cost", colors: [Color.green, Color.teal])
            }
        }
    }

    private func statTile(icon: String, value: String, label: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(value)
                .font(.satoshi(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.satoshi(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }

    // MARK: Timeline

    private func timelineHeader(_ day: DayItinerary) -> some View {
        HStack {
            Text("Timeline")
                .font(.satoshi(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            if day.stops.count > 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text(editMode.isEditing ? "Done" : "Reorder")
                            .font(.satoshi(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.9))
                }
                .buttonStyle(.plain)
            }
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
    }

    // MARK: Hidden gems

    private func hiddenGemsSection(_ gems: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing))
                Text("Hidden Gems")
                    .font(.satoshi(size: 18, weight: .bold))
            }
            FlowLayout(spacing: 8) {
                ForEach(gems, id: \.self) { gem in
                    Text(gem)
                        .font(.satoshi(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.18)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )
                        .overlay(
                            Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func tipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily tip")
                    .font(.satoshi(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(tip)
                    .font(.satoshi(size: 14, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trip highlights")
                .font(.satoshi(size: 18, weight: .bold))
            VStack(spacing: 8) {
                ForEach(Array(plan.highlights.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: index == 0 ? "crown.fill" : "sparkle")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Color.yellow, Color.pink], startPoint: .leading, endPoint: .trailing))
                            .padding(.top, 2)
                        Text(item)
                            .font(.satoshi(size: 14, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
                }
            }
        }
    }

    private var localTipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local tips")
                .font(.satoshi(size: 18, weight: .bold))
            VStack(spacing: 8) {
                ForEach(plan.localTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.green)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.satoshi(size: 14, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
                }
            }
        }
    }
}

// MARK: - Stop Card

private struct StopCard: View {
    let stop: Stop
    let isSelected: Bool
    let hasCoordinate: Bool
    let onTap: () -> Void
    let onOpenInMaps: () -> Void
    let onDelete: () -> Void
    var onSwap: (() -> Void)? = nil

    var body: some View {
        cardContent
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.primary.opacity(isSelected ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? accent.opacity(0.55) : Color.primary.opacity(0.05),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture(perform: onTap)
            .contextMenu {
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Soft numbered badge — calm tint instead of a bright gradient.
            ZStack {
                Circle().fill(accent.opacity(0.15))
                    .frame(width: 30, height: 30)
                Text("\(stop.order)")
                    .font(.satoshi(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Meta line: type icon + time · detail (quiet, single colour).
                HStack(spacing: 6) {
                    Image(systemName: stop.kind == .activity ? "figure.walk" : "fork.knife")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(metaText)
                        .font(.satoshi(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(stop.title)
                    .font(.satoshi(size: 16, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !stop.description.isEmpty {
                    Text(stop.description)
                        .font(.satoshi(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if stop.cost != nil || (stop.location.map { !$0.isEmpty } ?? false) {
                    HStack(spacing: 6) {
                        if let cost = stop.cost {
                            Text(cost)
                        }
                        if stop.cost != nil, let location = stop.location, !location.isEmpty {
                            Text("·").foregroundStyle(.tertiary)
                        }
                        if let location = stop.location, !location.isEmpty {
                            Text(location).lineLimit(1)
                        }
                    }
                    .font(.satoshi(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                if onSwap != nil || hasCoordinate {
                    HStack(spacing: 10) {
                        if let onSwap {
                            Button(action: onSwap) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                    Text("See alternatives")
                                }
                                .font(.satoshi(size: 12, weight: .semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                        if hasCoordinate {
                            Button(action: onOpenInMaps) {
                                HStack(spacing: 4) {
                                    Image(systemName: "map")
                                    Text("Directions")
                                }
                                .font(.satoshi(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    /// "Lunch · Mexican" or "4:00 PM · 3h".
    private var metaText: String {
        if let subtitle = stop.subtitle, !subtitle.isEmpty {
            return "\(stop.time) · \(subtitle)"
        }
        return stop.time
    }

    /// One calm accent per stop type — used as a low-opacity tint, not a fill.
    private var accent: Color {
        switch stop.kind {
        case .activity: return Color(red: 0.42, green: 0.45, blue: 0.92)
        case .restaurant: return Color(red: 0.90, green: 0.55, blue: 0.35)
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth == .infinity ? lineWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - List row styling

private extension View {
    /// Strips the default List chrome so custom cards keep their look inside a List.
    func plainRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }
}

// MARK: - Swap Sheet

private struct SwapSheet: View {
    @ObservedObject var editor: PlanEditorViewModel
    let dayId: String
    let activityId: String
    /// Notifies the map to re-geocode after a swap: (stopId, locationQuery).
    let onApplied: (_ stopId: String, _ query: String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var activity: Activity? {
        editor.plan.days.first(where: { $0.id == dayId })?
            .activities.first(where: { $0.id == activityId })
    }

    /// The cached pool of choices (original + alternatives), generated once.
    private var options: [ActivityOption] { activity?.swapOptions ?? [] }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else {
                    optionsList
                }
            }
            .navigationTitle("Swap activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadIfNeeded() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Finding alternatives…")
                .font(.satoshi(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            if let name = activity?.name {
                Text("For “\(name)”")
                    .font(.satoshi(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.satoshi(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task { await generate() }
            } label: {
                Text("Try again")
                    .font(.satoshi(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0.5, green: 0.3, blue: 0.9)))
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var optionsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Pick a version of this stop. Generated once — switch freely.")
                    .font(.satoshi(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(options) { option in
                    Button { choose(option) } label: {
                        optionCard(option, isCurrent: isCurrent(option))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    private func optionCard(_ option: ActivityOption, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.name)
                    .font(.satoshi(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if isCurrent {
                    Text("Current")
                        .font(.satoshi(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.12)))
                }
            }
            if !option.description.isEmpty {
                Text(option.description)
                    .font(.satoshi(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 12) {
                if let duration = option.duration {
                    Label(duration, systemImage: "clock")
                }
                if let cost = option.cost {
                    Label(cost, systemImage: "creditcard.fill")
                }
                if let location = option.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(.satoshi(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(isCurrent ? 0.08 : 0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrent ? Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.5) : Color.primary.opacity(0.08),
                        lineWidth: isCurrent ? 1.5 : 1)
        )
    }

    private func isCurrent(_ option: ActivityOption) -> Bool {
        option.name == activity?.name && option.description == activity?.description
    }

    /// Uses the cached pool when present; only calls the backend the first time.
    private func loadIfNeeded() async {
        if options.isEmpty {
            await generate()
        }
    }

    private func generate() async {
        guard let day = editor.plan.days.first(where: { $0.id == dayId }),
              var activity = day.activities.first(where: { $0.id == activityId }) else {
            dismiss()
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let alternatives = try await TravelPlanService.shared.swapActivity(
                plan: editor.plan, day: day, activity: activity
            )
            // Pool = the original (so the user can revert) + the AI alternatives.
            var pool = [activity.asOption]
            pool.append(contentsOf: alternatives.map {
                ActivityOption(name: $0.name, description: $0.description,
                               duration: $0.duration, cost: $0.cost, location: $0.location)
            })
            activity.swapOptions = pool
            editor.updateActivity(activity, dayId: dayId)
        } catch {
            errorMessage = "Couldn't load suggestions. Please try again."
        }
        isLoading = false
    }

    private func choose(_ option: ActivityOption) {
        guard let day = editor.plan.days.first(where: { $0.id == dayId }),
              var activity = day.activities.first(where: { $0.id == activityId }),
              !isCurrent(option) else { return }
        // Keep id, time, order, tips, and the cached pool; swap descriptive fields.
        activity.name = option.name
        activity.description = option.description
        activity.duration = option.duration
        activity.cost = option.cost
        activity.location = option.location
        editor.updateActivity(activity, dayId: dayId)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onApplied("act-\(activityId)", option.location ?? option.name)
        dismiss()
    }
}

