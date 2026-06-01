import SwiftUI
import MapKit
import CoreLocation

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
        let activityStops = activities.enumerated().map { _, a in
            Stop(
                id: "act-\(a.id)",
                kind: .activity,
                title: a.name,
                subtitle: a.duration,
                time: a.time,
                description: a.description,
                cost: a.cost,
                location: a.location,
                order: 0
            )
        }
        let restaurantStops = restaurants.enumerated().map { _, r in
            Stop(
                id: "res-\(r.id)",
                kind: .restaurant,
                title: r.name,
                subtitle: r.cuisine,
                time: r.time,
                description: r.description ?? (r.cuisine ?? ""),
                cost: r.priceRange,
                location: r.location,
                order: 0
            )
        }
        let combined = activityStops + restaurantStops
        let sorted = combined.sorted { lhs, rhs in
            sortKey(for: lhs.time) < sortKey(for: rhs.time)
        }
        return sorted.enumerated().map { index, stop in
            Stop(
                id: stop.id,
                kind: stop.kind,
                title: stop.title,
                subtitle: stop.subtitle,
                time: stop.time,
                description: stop.description,
                cost: stop.cost,
                location: stop.location,
                order: index + 1
            )
        }
    }

    private func sortKey(for timeString: String) -> Int {
        let lower = timeString.lowercased().trimmingCharacters(in: .whitespaces)
        let isPM = lower.contains("pm")
        let isAM = lower.contains("am")
        let digits = lower.filter { $0.isNumber || $0 == ":" }
        let parts = digits.split(separator: ":")
        var hour = Int(parts.first ?? "0") ?? 0
        let minute = Int(parts.dropFirst().first ?? "0") ?? 0
        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }
        if !isAM && !isPM {
            if lower.contains("lunch") { hour = 13 }
            else if lower.contains("dinner") { hour = 19 }
            else if lower.contains("breakfast") { hour = 8 }
        }
        return hour * 60 + minute
    }
}

// MARK: - Map Itinerary View

struct MapItineraryView: View {
    let plan: TravelPlan
    @Environment(\.dismiss) private var dismiss

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
                plan: plan,
                selectedDayIndex: $selectedDayIndex,
                selectedStopId: $selectedStopId,
                coordinates: coordinates,
                onStopTap: focusStop,
                onOpenInMaps: openInMaps
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
                if let coord = await geocoder.coordinate(for: query, near: destinationHint) {
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
    let plan: TravelPlan
    @Binding var selectedDayIndex: Int
    @Binding var selectedStopId: String?
    let coordinates: [String: CLLocationCoordinate2D]
    let onStopTap: (Stop) -> Void
    let onOpenInMaps: (Stop) -> Void

    private var currentDay: DayItinerary? {
        guard !plan.days.isEmpty else { return nil }
        return plan.days[min(selectedDayIndex, plan.days.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            daySelector
                .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        if let day = currentDay {
                            dayHeader(day)
                            timelineSection(day, proxy: proxy)
                            if !day.hiddenGems.isEmpty {
                                hiddenGemsSection(day.hiddenGems)
                            }
                            if let tip = day.tip {
                                tipCard(tip)
                            }
                        }

                        if !plan.highlights.isEmpty {
                            highlightsSection
                        }

                        if !plan.localTips.isEmpty {
                            localTipsSection
                        }

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .onChange(of: selectedStopId) { _, newId in
                    if let id = newId {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
        }
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

    private func timelineSection(_ day: DayItinerary, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Timeline")
                    .font(.satoshi(size: 18, weight: .bold))
                Spacer()
                if !day.stops.isEmpty {
                    Text("Tap a card to focus on the map")
                        .font(.satoshi(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(day.stops, id: \.id) { stop in
                    StopCard(
                        stop: stop,
                        isSelected: selectedStopId == stop.id,
                        hasCoordinate: coordinates[stop.id] != nil,
                        onTap: { onStopTap(stop) },
                        onOpenInMaps: { onOpenInMaps(stop) }
                    )
                    .id(stop.id)
                }
            }
        }
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

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(gradient)
                        .frame(width: 36, height: 36)
                    Text("\(stop.order)")
                        .font(.satoshi(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(stop.time)
                            .font(.satoshi(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                        if let subtitle = stop.subtitle, !subtitle.isEmpty {
                            Text("· \(subtitle)")
                                .font(.satoshi(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text(stop.kind == .activity ? "Activity" : "Eat")
                            .font(.satoshi(size: 10, weight: .bold))
                            .foregroundStyle(stop.kind == .activity ? Color.blue : Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill((stop.kind == .activity ? Color.blue : Color.orange).opacity(0.12)))
                    }
                    Text(stop.title)
                        .font(.satoshi(size: 16, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !stop.description.isEmpty {
                        Text(stop.description)
                            .font(.satoshi(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 10) {
                        if let cost = stop.cost {
                            Label(cost, systemImage: "creditcard.fill")
                                .font(.satoshi(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        if let location = stop.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.satoshi(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if hasCoordinate {
                            Button(action: onOpenInMaps) {
                                Image(systemName: "arrow.up.right.square.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.primary.opacity(isSelected ? 0.08 : 0.04))
            )
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(selectionStroke, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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

    private var selectionStroke: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.9, green: 0.4, blue: 0.6)],
            startPoint: .leading, endPoint: .trailing
        )
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
