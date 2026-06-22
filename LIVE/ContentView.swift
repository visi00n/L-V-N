//
//  ContentView.swift
//  LIVE
//
//  Created by Andrej Laptev on 6/17/26.
//

import Combine
import MapKit
import SwiftUI
import UIKit

private enum LiveSheet: Identifiable {
    case create
    case snap(LiveSnap)
    case profile(Explorer)
    case search
    case streaks
    case groups
    case route(LiveRoute)

    var id: String {
        switch self {
        case .create:
            "create"
        case .snap(let snap):
            "snap-\(snap.id)"
        case .profile(let explorer):
            "profile-\(explorer.id)"
        case .search:
            "search"
        case .streaks:
            "streaks"
        case .groups:
            "groups"
        case .route(let route):
            "route-\(route.id)"
        }
    }
}

private struct LiveRoute: Identifiable {
    let id = UUID()
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let label: String
}

struct ContentView: View {
    @StateObject private var locationStore = LocationStore()

    @State private var selectedTab: LiveTab = .events
    @State private var joinedEventIDs = Set(LiveData.signedUpEvents.map(\.id))
    @State private var activeSheet: LiveSheet?
    @State private var currentMapRegion = MKCoordinateRegion(
        center: LiveData.mapFallback,
        span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
    )
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: LiveData.mapFallback,
            span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )
    )

    var body: some View {
        ZStack {
            background

            Group {
                switch selectedTab {
                case .events:
                    HomeEventsView(
                        events: LiveData.events,
                        joinedEventIDs: joinedEventIDs,
                        onRoute: route,
                        onToggleJoin: toggleJoin
                    )
                case .map:
                    SnapMapView(
                        snaps: LiveData.snaps,
                        cameraPosition: $cameraPosition,
                        userCoordinate: locationStore.currentCoordinate,
                        locationStatus: locationStore.statusText,
                        onRequestLocation: centerOnUser,
                        onZoomIn: { zoomMap(by: 0.55) },
                        onZoomOut: { zoomMap(by: 1.55) },
                        onMapRegionChange: { currentMapRegion = $0 },
                        onSelectSnap: { activeSheet = .snap($0) }
                    )
                    .ignoresSafeArea()
                case .create:
                    Color.clear
                }
            }

            VStack(spacing: 0) {
                HeaderScrim()
                Spacer()
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                LiveTopBar(
                    streakCount: LiveData.me.streak,
                    onStreaks: { activeSheet = .streaks },
                    onGroups: { activeSheet = .groups },
                    onSearch: { activeSheet = .search },
                    onProfile: { activeSheet = .profile(LiveData.me) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()

                LiveBottomNav(
                    selectedTab: selectedTab,
                    onSelect: handleTabSelection
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .task {
            locationStore.requestLocation()
        }
        .onReceive(locationStore.$currentCoordinate.compactMap { $0 }) { coordinate in
            guard selectedTab == .map else { return }
            setMapRegion(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.16, longitudeDelta: 0.16)
                )
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                CreateSnapView(
                    locationStore: locationStore,
                    joinedEvents: LiveData.events.filter { joinedEventIDs.contains($0.id) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .snap(let snap):
                SnapDetailView(
                    snap: snap,
                    attachedEvent: LiveData.events.first { $0.id == snap.attachedEventID },
                    onRoute: route,
                    onProfile: { activeSheet = .profile(snap.creator) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .profile(let explorer):
                ProfileSheetView(explorer: explorer, snaps: LiveData.snaps.filter { $0.creator.id == explorer.id || explorer.id == LiveData.me.id })
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .search:
                SearchSheetView(
                    events: LiveData.events,
                    joinedEventIDs: joinedEventIDs,
                    onRoute: route,
                    onToggleJoin: toggleJoin
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .streaks:
                StreaksSheetView(streakCount: LiveData.me.streak)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            case .groups:
                GroupsSheetView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            case .route(let route):
                RoutePreviewView(liveRoute: route)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var background: some View {
        BrandBackdrop()
            .ignoresSafeArea()
    }

    private func handleTabSelection(_ tab: LiveTab) {
        if tab == .create {
            activeSheet = .create
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selectedTab = tab
        }

        if tab == .map {
            centerOnUser()
        }
    }

    private func centerOnUser() {
        locationStore.requestLocation()
        let coordinate = locationStore.displayCoordinate
        setMapRegion(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
            )
        )
    }

    private func zoomMap(by factor: CLLocationDegrees) {
        let latitudeDelta = min(max(currentMapRegion.span.latitudeDelta * factor, 0.01), 40)
        let longitudeDelta = min(max(currentMapRegion.span.longitudeDelta * factor, 0.01), 40)
        setMapRegion(
            MKCoordinateRegion(
                center: currentMapRegion.center,
                span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            )
        )
    }

    private func setMapRegion(_ region: MKCoordinateRegion, animated: Bool = true) {
        currentMapRegion = region
        let update = {
            cameraPosition = .region(region)
        }

        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86), update)
        } else {
            update()
        }
    }

    private func toggleJoin(_ event: LiveEvent) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            if joinedEventIDs.contains(event.id) {
                joinedEventIDs.remove(event.id)
            } else {
                joinedEventIDs.insert(event.id)
            }
        }
    }

    private func route(_ event: LiveEvent) {
        route(to: event.coordinate, label: event.locationName)
    }

    private func route(to coordinate: CLLocationCoordinate2D, label: String) {
        locationStore.requestLocation()
        activeSheet = .route(
            LiveRoute(
                origin: locationStore.displayCoordinate,
                destination: coordinate,
                label: label
            )
        )
    }
}

private struct RoutePreviewView: View {
    let liveRoute: LiveRoute

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var route: MKRoute?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(liveRoute: LiveRoute) {
        self.liveRoute = liveRoute
        _cameraPosition = State(initialValue: .region(Self.regionCovering(liveRoute.origin, liveRoute.destination)))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
                    Marker("You", systemImage: "location.fill", coordinate: liveRoute.origin)
                        .tint(Color.liveSky)

                    Marker(liveRoute.label, systemImage: "mappin.and.ellipse", coordinate: liveRoute.destination)
                        .tint(Color.liveCoral)

                    if let route {
                        MapPolyline(route.polyline)
                            .stroke(Color.liveSky, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .overlay {
                    MapMoodOverlay()
                }
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        PixelIconTile(size: 48, fill: Color.liveSky.opacity(0.18)) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.system(size: 23, weight: .black))
                                .foregroundStyle(Color.liveInk)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(liveRoute.label)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color.liveInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(routeSummary)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.liveMuted)
                        }

                        Spacer()
                    }

                    HStack(spacing: 10) {
                        RouteMetric(title: "Drive", value: travelTime)
                        RouteMetric(title: "Distance", value: distance)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMuted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.liveStroke, lineWidth: 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .shadow(color: Color.black.opacity(0.14), radius: 22, y: 12)
            }
            .navigationTitle("Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .task(id: liveRoute.id) {
                await loadRoute()
            }
        }
        .background(Color.liveCanvas)
    }

    private var routeSummary: String {
        if isLoading {
            return "Finding best route..."
        }

        if route == nil {
            return "Route preview unavailable"
        }

        return "Best available driving route"
    }

    private var travelTime: String {
        guard let route else { return isLoading ? "--" : "N/A" }
        let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private var distance: String {
        guard let route else { return isLoading ? "--" : "N/A" }
        return String(format: "%.1f mi", route.distance / 1_609.344)
    }

    private func loadRoute() async {
        isLoading = true
        errorMessage = nil

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: liveRoute.origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: liveRoute.destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        do {
            let response = try await MKDirections(request: request).calculate()
            route = response.routes.min { $0.expectedTravelTime < $1.expectedTravelTime }
            cameraPosition = .region(Self.regionCovering(liveRoute.origin, liveRoute.destination))
        } catch {
            route = nil
            errorMessage = "Could not load directions from this location yet."
        }

        isLoading = false
    }

    private static func regionCovering(_ origin: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let minLatitude = min(origin.latitude, destination.latitude)
        let maxLatitude = max(origin.latitude, destination.latitude)
        let minLongitude = min(origin.longitude, destination.longitude)
        let maxLongitude = max(origin.longitude, destination.longitude)
        let latitudeDelta = max(0.05, (maxLatitude - minLatitude) * 1.8)
        let longitudeDelta = max(0.05, (maxLongitude - minLongitude) * 1.8)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private struct RouteMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct MapMoodOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                ? [Color.liveSky.opacity(0.22), Color.clear, Color.liveLavender.opacity(0.24)]
                : [Color.liveSky.opacity(0.14), Color.clear, Color.liveCoral.opacity(0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(colorScheme == .dark ? .screen : .softLight)

            Color.liveCanvas
                .opacity(colorScheme == .dark ? 0.11 : 0.03)
                .blendMode(colorScheme == .dark ? .multiply : .plusLighter)
        }
        .allowsHitTesting(false)
    }
}

private struct LiveTopBar: View {
    let streakCount: Int
    let onStreaks: () -> Void
    let onGroups: () -> Void
    let onSearch: () -> Void
    let onProfile: () -> Void

    var body: some View {
        ZStack {
            Text("L!V!N")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.liveSky, Color.liveLavender, Color.liveCoral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 10) {
                PixelIconButton(label: "Streaks", content: {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .black))
                }, action: onStreaks)
                .overlay(alignment: .topTrailing) {
                    Text("\(streakCount)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.liveInk)
                        .frame(width: 18, height: 18)
                        .background(Color.liveLemon, in: RoundedRectangle(cornerRadius: 5))
                        .offset(x: 4, y: -4)
                }

                PixelIconButton(label: "Groups", content: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 17, weight: .black))
                }, action: onGroups)

                Spacer()

                PixelIconButton(label: "Search", content: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .black))
                }, action: onSearch)

                Button(action: onProfile) {
                    PixelIconTile(size: 38, fill: Color.liveSurfaceElevated.opacity(0.86)) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Color.liveInk)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")
            }
        }
        .frame(height: 48)
    }
}

private struct HeaderScrim: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.liveCanvas,
                Color.liveCanvas.opacity(0.94),
                Color.liveCanvas.opacity(0.72),
                Color.liveCanvas.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 154)
        .ignoresSafeArea(edges: .top)
    }
}

private struct BrandBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.liveCanvas

            LinearGradient(
                colors: colorScheme == .dark
                ? [
                    Color(red: 0.03, green: 0.04, blue: 0.14),
                    Color(red: 0.09, green: 0.06, blue: 0.22),
                    Color(red: 0.04, green: 0.04, blue: 0.14)
                ]
                : [
                    Color(red: 0.82, green: 0.93, blue: 1.0),
                    Color(red: 0.94, green: 0.88, blue: 1.0),
                    Color(red: 1.0, green: 0.88, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 0.92 : 0.76)

            GeometryReader { proxy in
                let size = proxy.size

                BrandWave(progress: 0.16)
                    .stroke(Color.liveSky.opacity(colorScheme == .dark ? 0.30 : 0.34), style: StrokeStyle(lineWidth: 54, lineCap: .round, lineJoin: .round))
                    .frame(width: size.width * 1.28, height: size.height * 0.54)
                    .offset(x: -size.width * 0.20, y: size.height * 0.04)

                BrandWave(progress: 0.62)
                    .stroke(Color.liveLavender.opacity(colorScheme == .dark ? 0.26 : 0.24), style: StrokeStyle(lineWidth: 74, lineCap: .round, lineJoin: .round))
                    .frame(width: size.width * 1.36, height: size.height * 0.58)
                    .offset(x: -size.width * 0.10, y: size.height * 0.33)

                BrandWave(progress: 0.88)
                    .stroke(Color.liveCoral.opacity(colorScheme == .dark ? 0.22 : 0.20), style: StrokeStyle(lineWidth: 48, lineCap: .round, lineJoin: .round))
                    .frame(width: size.width * 1.18, height: size.height * 0.42)
                    .offset(x: size.width * 0.02, y: size.height * 0.66)

                VStack {
                    HStack {
                        FlowerMark()
                            .fill(Color.liveCoral.opacity(colorScheme == .dark ? 0.20 : 0.30))
                            .frame(width: 84, height: 84)
                            .rotationEffect(.degrees(-14))
                            .offset(x: -28, y: 112)

                        Spacer()
                    }

                    Spacer()

                    HStack {
                        Spacer()

                        FlowerMark()
                            .fill(Color.liveSky.opacity(colorScheme == .dark ? 0.20 : 0.28))
                            .frame(width: 104, height: 104)
                            .rotationEffect(.degrees(18))
                            .offset(x: 42, y: -112)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct BrandWave: Shape {
    let progress: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.height * progress
        path.move(to: CGPoint(x: rect.minX - rect.width * 0.08, y: y))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height * (1 - progress * 0.42)),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * (progress - 0.32)),
            control2: CGPoint(x: rect.width * 0.32, y: rect.height * (progress + 0.36))
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX + rect.width * 0.10, y: rect.height * (progress + 0.10)),
            control1: CGPoint(x: rect.width * 0.68, y: rect.height * (progress - 0.28)),
            control2: CGPoint(x: rect.width * 0.84, y: rect.height * (progress + 0.32))
        )
        return path
    }
}

private struct FlowerMark: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.22
        var path = Path()

        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let petalCenter = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            path.addEllipse(in: CGRect(
                x: petalCenter.x - radius * 0.74,
                y: petalCenter.y - radius * 1.16,
                width: radius * 1.48,
                height: radius * 2.32
            ))
        }

        path.addEllipse(in: CGRect(
            x: center.x - radius * 0.66,
            y: center.y - radius * 0.66,
            width: radius * 1.32,
            height: radius * 1.32
        ))
        return path
    }
}

private struct PixelIconButton<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PixelIconTile(size: 38, fill: Color.liveSurfaceElevated.opacity(0.86)) {
                content()
                    .foregroundStyle(Color.liveInk)
            }
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct PixelIconTile<Content: View>: View {
    let size: CGFloat
    let fill: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fill)

            PixelCornerMarks()
                .stroke(Color.liveInk.opacity(0.14), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                .padding(5)

            content()
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
    }
}

private struct PixelCornerMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) * 0.22
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + unit))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + unit, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - unit, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + unit))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - unit))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - unit, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + unit, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - unit))

        return path
    }
}

private struct HomeEventsView: View {
    let events: [LiveEvent]
    let joinedEventIDs: Set<String>
    let onRoute: (LiveEvent) -> Void
    let onToggleJoin: (LiveEvent) -> Void

    @State private var expandedEntryID: String?
    @State private var tapHaptic = UISelectionFeedbackGenerator()
    @State private var scrollHaptic = UISelectionFeedbackGenerator()

    private var visibleEvents: [LiveEvent] {
        guard !events.isEmpty else { return [] }
        return Array(events.prefix(20))
    }

    private var eventEntries: [EventDeckEntry] {
        visibleEvents.map { event in
            EventDeckEntry(id: event.id, event: event)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 7) {
                    ForEach(eventEntries) { entry in
                        EventFeedCard(
                            event: entry.event,
                            isJoined: joinedEventIDs.contains(entry.event.id),
                            isShowingDetails: expandedEntryID == entry.id,
                            onToggleDetails: {
                                tapHaptic.selectionChanged()
                                tapHaptic.prepare()
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                    expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                                }
                            },
                            onRoute: { onRoute(entry.event) },
                            onToggleJoin: { onToggleJoin(entry.event) }
                        )
                        .id(entry.id)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 126)
                .padding(.bottom, 150)
            }
            .onScrollGeometryChange(for: Int.self) { geometry in
                Int(max(0, geometry.contentOffset.y) / 82)
            } action: { oldTick, newTick in
                guard oldTick != newTick else { return }
                scrollHaptic.selectionChanged()
                scrollHaptic.prepare()
            }
        }
        .background(BrandBackdrop())
        .onAppear {
            tapHaptic.prepare()
            scrollHaptic.prepare()
        }
    }
}

private struct EventDeckEntry: Identifiable {
    let id: String
    let event: LiveEvent
}

private struct EventFeedCard: View {
    let event: LiveEvent
    let isJoined: Bool
    let isShowingDetails: Bool
    let onToggleDetails: () -> Void
    let onRoute: () -> Void
    let onToggleJoin: () -> Void

    var body: some View {
        Group {
            if isShowingDetails {
                EventBackCard(
                    event: event,
                    isJoined: isJoined,
                    onFlip: onToggleDetails,
                    onRoute: onRoute,
                    onToggleJoin: onToggleJoin
                )
                .accessibilityAction(named: Text("Close details"), onToggleDetails)
            } else {
                Button(action: onToggleDetails) {
                    EventFrontCard(event: event, isJoined: isJoined)
                }
                .buttonStyle(.plain)
            }
        }
        .background(event.palette.cardGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(event.palette.primary.opacity(0.28), lineWidth: 1.2)
        }
        .shadow(color: event.palette.primary.opacity(0.16), radius: 20, y: 9)
        .shadow(color: Color.black.opacity(0.045), radius: 11, y: 5)
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: isShowingDetails)
    }
}

private struct EventFrontCard: View {
    let event: LiveEvent
    let isJoined: Bool

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                ExplorerAvatar(explorer: event.host, size: 24)

                Text(event.host.handle)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)
                    .lineLimit(1)

                Spacer()

                EventBadge(text: event.feedBadge, color: event.feedBadgeColor)

                if isJoined {
                    EventBadge(text: "Signed", color: Color.liveMint)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Text(event.title.uppercased())
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(Color.liveInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: .infinity, alignment: .leading)

                EventThumbnail(event: event)
            }

            HStack(spacing: 8) {
                CompactMeta(symbolName: "mappin", text: event.locationName)
                CompactMeta(symbolName: "clock.fill", text: event.timeLabel)
                CompactMeta(symbolName: "person.2.fill", text: "\(event.attendeeCount)")
                CompactMeta(symbolName: "dollarsign.circle.fill", text: event.priceLabel)
            }

            Text("LIVE FEED")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.liveInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.liveInk.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(11)
    }
}

private struct EventBackCard: View {
    let event: LiveEvent
    let isJoined: Bool
    let onFlip: () -> Void
    let onRoute: () -> Void
    let onToggleJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                EventThumbnail(event: event)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("\(event.locationName) - \(event.timeLabel)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.liveMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }

                Spacer()

                Button(action: onFlip) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.liveInk)
                        .frame(width: 34, height: 34)
                        .background(Color.liveSurfaceElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onFlip)

            Text(event.details)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture(perform: onFlip)

            HStack(spacing: 8) {
                DetailPill(symbolName: "person.fill", text: event.host.handle)
                DetailPill(symbolName: "person.2.fill", text: "\(event.attendeeCount) going")
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onFlip)

            HStack(spacing: 10) {
                Button(action: onRoute) {
                    Label("Route", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.liveSurfaceElevated.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button(action: onToggleJoin) {
                    Label(isJoined ? "Signed Up" : "Sign Up", systemImage: isJoined ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(event.palette.primary.opacity(isJoined ? 0.26 : 0.15), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
}

private struct EventBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(Color.liveInk)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CompactMeta: View {
    let symbolName: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.liveInk)

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveInk.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EventThumbnail: View {
    let event: LiveEvent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(event.palette.softFill)

            PixelIconTile(size: 42, fill: event.palette.primary.opacity(0.18)) {
                Image(systemName: event.palette.symbolName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.liveInk)
            }
        }
        .frame(width: 58, height: 52)
        .overlay {
            PixelCornerMarks()
                .stroke(Color.liveInk.opacity(0.14), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                .padding(6)
        }
    }
}

private struct EventPoster: View {
    let event: LiveEvent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(event.palette.gradient)

            PixelIconTile(size: 58, fill: Color.white.opacity(0.18)) {
                Image(systemName: event.palette.symbolName)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color.liveInk)
            }

            VStack {
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(8)
        }
        .frame(width: 94, height: 108)
    }
}

private struct DetailPill: View {
    let symbolName: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            PixelMiniSymbol(symbolName: symbolName, color: Color.liveInk)

            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(Color.liveInk.opacity(0.75))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.liveCanvas.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PixelMiniSymbol: View {
    let symbolName: String
    let color: Color

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(Color.liveSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                PixelCornerMarks()
                    .stroke(color.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, lineCap: .square, lineJoin: .miter))
                    .padding(3)
            }
    }
}

private struct SnapMapView: View {
    let snaps: [LiveSnap]
    @Binding var cameraPosition: MapCameraPosition
    let userCoordinate: CLLocationCoordinate2D?
    let locationStatus: String
    let onRequestLocation: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onMapRegionChange: (MKCoordinateRegion) -> Void
    let onSelectSnap: (LiveSnap) -> Void

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            UserAnnotation()

            ForEach(snaps) { snap in
                Annotation(snap.title, coordinate: snap.coordinate, anchor: .bottom) {
                    Button {
                        onSelectSnap(snap)
                    } label: {
                        SnapPhotoPin(snap: snap)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            onMapRegionChange(context.region)
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .overlay {
            MapMoodOverlay()
        }
        .overlay(alignment: .topLeading) {
            Button(action: onRequestLocation) {
                HStack(spacing: 7) {
                    Image(systemName: userCoordinate == nil ? "location.circle" : "location.fill")
                        .font(.system(size: 12, weight: .black))

                    Text(locationStatus)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color.liveInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.liveStroke, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 168)
            .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            MapZoomControls(onZoomIn: onZoomIn, onZoomOut: onZoomOut)
                .padding(.top, 168)
                .padding(.trailing, 16)
        }
    }
}

private struct MapZoomControls: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            zoomButton(symbolName: "plus", label: "Zoom in", action: onZoomIn)
            zoomButton(symbolName: "minus", label: "Zoom out", action: onZoomOut)
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
        .shadow(color: Color.liveSky.opacity(0.36), radius: 18, y: 0)
    }

    private func zoomButton(symbolName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.liveInk)
                .frame(width: 31, height: 31)
                .background(Color.liveSurfaceElevated.opacity(0.88), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct SnapPhotoPin: View {
    let snap: LiveSnap

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(snap.palette.gradient)
                .frame(width: 66, height: 78)
                .overlay(alignment: .center) {
                    PixelIconTile(size: 42, fill: Color.white.opacity(0.16)) {
                        Image(systemName: snap.palette.symbolName)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Color.liveInk)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                }
                .overlay {
                    PixelCornerMarks()
                        .stroke(Color.white.opacity(0.52), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                        .padding(7)
                }
                .shadow(color: snap.palette.primary.opacity(0.3), radius: 16, y: 9)

            if snap.imageCount > 1 {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.liveInk)
                    .frame(width: 28, height: 28)
                    .background(Color.white, in: Circle())
                    .offset(x: 10, y: -10)
            }

            VStack {
                Spacer()
                Text(snap.creator.handle)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
        }
        .accessibilityLabel("\(snap.title), \(snap.imageCount) photos")
    }
}

private struct SnapDetailView: View {
    let snap: LiveSnap
    let attachedEvent: LiveEvent?
    let onRoute: (LiveEvent) -> Void
    let onProfile: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(snap.palette.gradient)
                        .frame(height: 290)

                    PixelIconTile(size: 112, fill: Color.white.opacity(0.16)) {
                        Image(systemName: snap.palette.symbolName)
                            .font(.system(size: 62, weight: .black))
                            .foregroundStyle(Color.liveInk)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 290)

                    if snap.imageCount > 1 {
                        Label("\(snap.imageCount)", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.liveInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.88), in: Capsule())
                            .padding(12)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onProfile) {
                        HStack(spacing: 9) {
                            ExplorerAvatar(explorer: snap.creator, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.creator.handle)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)

                                Text(snap.timeLabel)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.liveMuted)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Label(snap.locationName, systemImage: "mappin")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.liveInk)
                }

                Text(snap.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)

                Text(snap.caption)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let attachedEvent {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Part of event")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveMuted)

                        HStack(spacing: 11) {
                            EventPoster(event: attachedEvent)
                                .frame(width: 70, height: 78)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(attachedEvent.title)
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)

                                Text("\(attachedEvent.locationName) - \(attachedEvent.timeLabel)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.liveMuted)
                            }

                            Spacer()

                            Button {
                                onRoute(attachedEvent)
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(Color.liveInk)
                                    .frame(width: 38, height: 38)
                                    .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(18)
        }
        .background(Color.liveCanvas)
    }
}

private struct CreateSnapView: View {
    @ObservedObject var locationStore: LocationStore
    let joinedEvents: [LiveEvent]

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var photoCount = 1
    @State private var isPartOfEvent = false
    @State private var selectedEventID: String?
    @State private var capturedImage: UIImage?
    @State private var isCameraPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.liveSurfaceElevated)
                            .frame(height: 315)

                        VStack(spacing: 15) {
                            if let capturedImage {
                                Image(uiImage: capturedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 190, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.liveInk.opacity(0.08), lineWidth: 1)
                                    }
                            } else {
                                PixelIconTile(size: 86, fill: Color.liveCanvas.opacity(0.9)) {
                                    Image(systemName: "camera.aperture")
                                        .font(.system(size: 48, weight: .black))
                                        .foregroundStyle(Color.liveInk)
                                }
                            }

                            Text("Create live snap")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Color.liveInk)

                            Text("Your first picture shows on the map. Add more and it becomes a slideshow.")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.liveMuted)
                                .padding(.horizontal, 28)

                            Button {
                                isCameraPresented = true
                            } label: {
                                Label(capturedImage == nil ? "Open camera" : "Retake", systemImage: "camera.fill")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.liveInk.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 315)

                        if photoCount > 1 {
                            Label("\(photoCount)", systemImage: "rectangle.stack.fill")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.liveInk)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.liveSurfaceElevated.opacity(0.9), in: Capsule())
                                .padding(12)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            if photoCount > 1 {
                                photoCount -= 1
                            }
                        } label: {
                            PixelIconTile(size: 44, fill: Color.liveSurfaceElevated.opacity(0.86)) {
                                Image(systemName: "minus")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Color.liveInk)
                            }
                        }
                        .buttonStyle(.plain)

                        Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))

                        Button {
                            photoCount += 1
                        } label: {
                            PixelIconTile(size: 44, fill: Color.liveSurfaceElevated.opacity(0.86)) {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Color.liveInk)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    LocationLockRow(locationStore: locationStore)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Snap caption")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        TextEditor(text: $caption)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(minHeight: 112)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.liveLavender.opacity(0.24), lineWidth: 1)
                            }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("WAS THIS PART OF EVENTT")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        HStack(spacing: 8) {
                            YesNoButton(title: "No", isSelected: !isPartOfEvent) {
                                isPartOfEvent = false
                                selectedEventID = nil
                            }
                            YesNoButton(title: "Yes", isSelected: isPartOfEvent) {
                                isPartOfEvent = true
                                selectedEventID = selectedEventID ?? joinedEvents.first?.id
                            }
                        }

                        if isPartOfEvent {
                            if joinedEvents.isEmpty {
                                Text("Sign up for an event first, then attach your live snap here.")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.liveMuted)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
                            } else {
                                Picker("Attach event", selection: Binding(
                                    get: { selectedEventID ?? joinedEvents[0].id },
                                    set: { selectedEventID = $0 }
                                )) {
                                    ForEach(joinedEvents) { event in
                                        Text(event.title).tag(event.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Post live snap")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
            .background(Color.liveCanvas)
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
        .onAppear {
            locationStore.requestLocation()
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraCaptureView(image: $capturedImage)
                .ignoresSafeArea()
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var image: UIImage?
        private let dismiss: DismissAction

        init(image: Binding<UIImage?>, dismiss: DismissAction) {
            _image = image
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            image = info[.originalImage] as? UIImage
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct LocationLockRow: View {
    @ObservedObject var locationStore: LocationStore

    var body: some View {
        Button {
            locationStore.requestLocation()
        } label: {
            HStack(spacing: 12) {
                PixelIconTile(size: 42, fill: Color.liveSky.opacity(0.18)) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.liveInk)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Current location required")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)

                    Text(locationStore.statusText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                }

                Spacer()
            }
            .padding(11)
            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct YesNoButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.liveInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isSelected ? AnyShapeStyle(Color.liveInk) : AnyShapeStyle(Color.liveSurface), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct LiveBottomNav: View {
    let selectedTab: LiveTab
    let onSelect: (LiveTab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LiveTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 2) {
                        PixelIconTile(size: tab == .create ? 29 : 27, fill: iconFill(for: tab)) {
                            Image(systemName: tab.symbolName)
                                .font(.system(size: tab == .create ? 17 : 15, weight: .black))
                                .foregroundStyle(foreground(for: tab))
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(foreground(for: tab))
                    .frame(width: tab == .create ? 64 : 58, height: 50)
                    .background(backgroundStyle(for: tab), in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: glowColor(for: tab), radius: 12, y: 0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
    }

    private func foreground(for tab: LiveTab) -> Color {
        Color.liveInk
    }

    private func iconFill(for tab: LiveTab) -> Color {
        if tab == .create || tab == selectedTab {
            Color.liveSurfaceElevated.opacity(0.84)
        } else {
            Color.liveSurface.opacity(0.72)
        }
    }

    private func backgroundStyle(for tab: LiveTab) -> AnyShapeStyle {
        if tab == .create {
            AnyShapeStyle(Color.liveLavender.opacity(0.24))
        } else if tab == .map && tab == selectedTab {
            AnyShapeStyle(Color.liveSky.opacity(0.24))
        } else if tab == selectedTab {
            AnyShapeStyle(Color.liveSurfaceElevated.opacity(0.78))
        } else {
            AnyShapeStyle(Color.clear)
        }
    }

    private func glowColor(for tab: LiveTab) -> Color {
        tab == .map && tab == selectedTab ? Color.liveSky.opacity(0.32) : Color.clear
    }
}

private struct ExplorerAvatar: View {
    let explorer: Explorer
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.liveLavender.opacity(0.2))
                .frame(width: size, height: size)

            Image(systemName: explorer.avatarSymbolName)
                .font(.system(size: size * 0.43, weight: .black))
                .foregroundStyle(Color.liveInk)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        }
        .overlay {
            PixelCornerMarks()
                .stroke(Color.liveInk.opacity(0.16), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                .padding(6)
        }
    }
}

private struct SearchSheetView: View {
    let events: [LiveEvent]
    let joinedEventIDs: Set<String>
    let onRoute: (LiveEvent) -> Void
    let onToggleJoin: (LiveEvent) -> Void

    @State private var query = ""
    @State private var expandedEventID: String?

    private var filteredEvents: [LiveEvent] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return events }

        return events.filter { event in
            event.title.localizedCaseInsensitiveContains(trimmedQuery)
            || event.locationName.localizedCaseInsensitiveContains(trimmedQuery)
            || event.category.localizedCaseInsensitiveContains(trimmedQuery)
            || event.host.handle.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.liveInk)

                        TextField("Search events, places, hosts", text: $query)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .textInputAutocapitalization(.never)
                    }
                    .padding(13)
                    .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.liveStroke, lineWidth: 1)
                    }

                    ForEach(filteredEvents) { event in
                        EventFeedCard(
                            event: event,
                            isJoined: joinedEventIDs.contains(event.id),
                            isShowingDetails: expandedEventID == event.id,
                            onToggleDetails: {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                                    expandedEventID = expandedEventID == event.id ? nil : event.id
                                }
                            },
                            onRoute: { onRoute(event) },
                            onToggleJoin: { onToggleJoin(event) }
                        )
                    }

                    if filteredEvents.isEmpty {
                        Text("No events found")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                }
                .padding(18)
            }
            .background(Color.liveCanvas)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ProfileSheetView: View {
    let explorer: Explorer
    let snaps: [LiveSnap]

    @State private var accountPrivacy: AccountPrivacy = .privateAccount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 13) {
                    ExplorerAvatar(explorer: explorer, size: 66)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(explorer.displayName)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        Text(explorer.handle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMuted)
                    }
                }

                Text(explorer.bio)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)

                HStack(spacing: 8) {
                    MetricBox(title: "Score", value: "\(explorer.ventureScore)")
                    MetricBox(title: "Streak", value: "\(explorer.streak)d")
                    MetricBox(title: "Snaps", value: "\(snaps.count)")
                }

                if explorer.id == LiveData.me.id {
                    AccountSettingsCard(selection: $accountPrivacy)
                }

                if !snaps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Map memories")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        Map(position: .constant(.region(region(for: snaps)))) {
                            ForEach(snaps) { snap in
                                Annotation(snap.title, coordinate: snap.coordinate, anchor: .bottom) {
                                    SnapPhotoPin(snap: snap)
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .flat))
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .disabled(true)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.liveCanvas)
    }

    private func region(for snaps: [LiveSnap]) -> MKCoordinateRegion {
        let coordinates = snaps.map(\.coordinate)
        let minLatitude = coordinates.map(\.latitude).min() ?? LiveData.mapFallback.latitude
        let maxLatitude = coordinates.map(\.latitude).max() ?? LiveData.mapFallback.latitude
        let minLongitude = coordinates.map(\.longitude).min() ?? LiveData.mapFallback.longitude
        let maxLongitude = coordinates.map(\.longitude).max() ?? LiveData.mapFallback.longitude

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.08, (maxLatitude - minLatitude) * 1.8),
                longitudeDelta: max(0.08, (maxLongitude - minLongitude) * 1.8)
            )
        )
    }
}

private enum AccountPrivacy: String, CaseIterable, Identifiable {
    case privateAccount = "Private"
    case publicAccount = "Public"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .privateAccount:
            "Only friends can see your map memories."
        case .publicAccount:
            "Public snaps can show on the map."
        }
    }

    var symbolName: String {
        switch self {
        case .privateAccount:
            "lock.fill"
        case .publicAccount:
            "globe.americas.fill"
        }
    }
}

private struct AccountSettingsCard: View {
    @Binding var selection: AccountPrivacy

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PixelIconTile(size: 38, fill: Color.liveLemon.opacity(0.78)) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.liveInk)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)

                    Text(selection.detail)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                }
            }

            HStack(spacing: 8) {
                ForEach(AccountPrivacy.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                            selection = option
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: option.symbolName)
                                .font(.system(size: 13, weight: .black))

                            Text(option.rawValue)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(Color.liveInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selection == option ? AnyShapeStyle(Color.liveSky.opacity(0.18)) : AnyShapeStyle(Color.liveSurface), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(13)
        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
    }
}

private struct MetricBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StreaksSheetView: View {
    let streakCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                PixelIconTile(size: 46, fill: Color.liveLemon.opacity(0.82)) {
                    Image(systemName: "calendar")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.liveInk)
                }

                Text("\(streakCount) day streak")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)
            }

            Text("Keep it alive by posting a live snap after you actually go somewhere.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.liveMuted)

            StreakCalendarView(streakCount: streakCount)

            HStack(spacing: 10) {
                MetricBox(title: "Today", value: "+10")
                MetricBox(title: "Week", value: "+40")
                MetricBox(title: "Next", value: "5d")
            }

            Spacer()
        }
        .padding(20)
        .background(Color.liveCanvas)
    }
}

private struct StreakCalendarView: View {
    let streakCount: Int

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.liveInk)

                Text("Streak calendar")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)
            }

            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 6) {
                        Text(day)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.liveMuted)

                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(index < min(streakCount, days.count) ? Color.liveSky.opacity(0.18) : Color.liveSurface)

                            Image(systemName: index < min(streakCount, days.count) ? "checkmark" : "circle")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.liveInk)
                        }
                        .frame(height: 34)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
    }
}

private struct GroupsSheetView: View {
    private let groups = [
        ("Beach Crew", "Volleyball, sunsets, beach runs", "figure.volleyball", SnapPalette.coral),
        ("Trail Mix", "Hikes and lookout spots", "figure.hiking", SnapPalette.mint),
        ("Night Crew", "Games, food, last-minute hangs", "sparkles", SnapPalette.lavender)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Groups")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            VStack(spacing: 10) {
                ForEach(groups, id: \.0) { group in
                    HStack(spacing: 12) {
                        Image(systemName: group.2)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.liveInk)
                            .frame(width: 48, height: 48)
                            .background(group.3.gradient, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                PixelCornerMarks()
                                    .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                                    .padding(6)
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.0)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Color.liveInk)

                            Text(group.1)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.liveMuted)
                        }

                        Spacer()
                    }
                    .padding(11)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.liveCanvas)
    }
}

private extension SnapPalette {
    var primary: Color {
        switch self {
        case .coral:
            Color.liveCoral
        case .mint:
            Color.liveMint
        case .lavender:
            Color.liveLavender
        case .sky:
            Color.liveSky
        case .lemon:
            Color.liveLemon
        }
    }

    var secondary: Color {
        switch self {
        case .coral:
            Color(red: 0.99, green: 0.59, blue: 0.74)
        case .mint:
            Color(red: 0.49, green: 0.86, blue: 0.78)
        case .lavender:
            Color(red: 0.66, green: 0.66, blue: 0.96)
        case .sky:
            Color(red: 0.47, green: 0.80, blue: 0.96)
        case .lemon:
            Color(red: 0.99, green: 0.78, blue: 0.38)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.58), secondary.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var softFill: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.22), secondary.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                primary.opacity(0.24),
                secondary.opacity(0.18),
                Color.liveSurfaceElevated.opacity(0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension EventPulse {
    var label: String {
        switch self {
        case .fresh:
            "New"
        case .soon:
            "Soon"
        case .steady:
            ""
        }
    }

    var glowColor: Color {
        switch self {
        case .fresh:
            Color.liveNeonGreen
        case .soon:
            Color.liveAlertRed
        case .steady:
            Color.clear
        }
    }

    var strokeColor: Color {
        switch self {
        case .fresh, .soon:
            glowColor.opacity(0.34)
        case .steady:
            Color.liveCanvas.opacity(0.82)
        }
    }

    var glowOpacity: Double {
        switch self {
        case .fresh:
            0.42
        case .soon:
            0.5
        case .steady:
            0
        }
    }
}

private extension LiveEvent {
    var feedBadge: String {
        if pulse == .fresh {
            return "New"
        }

        if pulse == .soon {
            return "Soon"
        }

        return category
    }

    var feedBadgeColor: Color {
        switch pulse {
        case .fresh:
            Color.liveNeonGreen
        case .soon:
            Color.liveAlertRed
        case .steady:
            palette.primary
        }
    }
}

private extension Color {
    static let liveInk = dynamicColor(
        light: UIColor(red: 0.05, green: 0.07, blue: 0.17, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 1)
    )
    static let liveMuted = dynamicColor(
        light: UIColor(red: 0.35, green: 0.38, blue: 0.53, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.70, blue: 0.86, alpha: 1)
    )
    static let liveCanvas = dynamicColor(
        light: UIColor(red: 0.91, green: 0.95, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.045, blue: 0.11, alpha: 1)
    )
    static let liveSurface = dynamicColor(
        light: UIColor(red: 0.97, green: 0.985, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.105, blue: 0.20, alpha: 1)
    )
    static let liveSurfaceElevated = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.145, blue: 0.27, alpha: 1)
    )
    static let liveStroke = dynamicColor(
        light: UIColor(red: 0.73, green: 0.79, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.27, green: 0.31, blue: 0.48, alpha: 1)
    )
    static let liveCoral = Color(red: 0.98, green: 0.22, blue: 0.58)
    static let liveMint = Color(red: 0.00, green: 0.82, blue: 0.92)
    static let liveLavender = Color(red: 0.48, green: 0.35, blue: 0.95)
    static let liveSky = Color(red: 0.05, green: 0.42, blue: 0.98)
    static let liveLemon = Color(red: 0.74, green: 0.66, blue: 1.0)
    static let liveNeonGreen = Color(red: 0.00, green: 0.70, blue: 0.95)
    static let liveAlertRed = Color(red: 1.0, green: 0.25, blue: 0.56)

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

#Preview {
    ContentView()
}
