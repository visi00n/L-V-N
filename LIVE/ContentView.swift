//
//  ContentView.swift
//  LIVE
//
//  Created by Andrej Laptev on 6/17/26.
//

import Combine
import CoreLocation
import MapKit
import PhotosUI
import Supabase
import Storage
import SwiftUI
import UIKit

private enum LiveSheet: Identifiable {
    case create
    case createEvent
    case snap(LiveSnap)
    case event(LiveEvent)
    case eventSnaps(LiveEvent)
    case eventChat(LiveEvent)
    case directMessage(Explorer)
    case search
    case streaks
    case groups
    case route(LiveRoute)

    var id: String {
        switch self {
        case .create:
            "create"
        case .createEvent:
            "create-event"
        case .snap(let snap):
            "snap-\(snap.id)"
        case .event(let event):
            "event-\(event.id)"
        case .eventSnaps(let event):
            "event-snaps-\(event.id)"
        case .eventChat(let event):
            "chat-\(event.id)"
        case .directMessage(let explorer):
            "direct-message-\(explorer.id)"
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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationStore = LocationStore()
    @StateObject private var authManager = AuthManager()
    @StateObject private var snapMapViewModel = SnapMapViewModel()
    @StateObject private var eventViewModel = EventViewModel()

    @State private var selectedTab: LiveTab = .events
    @State private var eventRadius: EventRadius = .twentyFive
    @State private var mapMode: MapMode = .public
    @State private var activeSheet: LiveSheet?
    @State private var fullScreenProfile: Explorer?
    @AppStorage("streakCount") private var streakCount: Int = 1
    @AppStorage("lastAppOpenDate") private var lastAppOpenDate: Double = 0
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

    private var visibleSnaps: [LiveSnap] {
        let baseSnaps = mapMode == .personal ? snapMapViewModel.snaps.filter { $0.creator.id == authManager.profile?.id.uuidString } : snapMapViewModel.snaps

        let zoom = currentMapRegion.span.longitudeDelta
        if zoom > 1.5 {
            return []
        }
        if zoom > 0.35 {
            return Array(baseSnaps.sorted(by: snapRelevanceSort).prefix(6))
        }
        if zoom > 0.12 {
            return Array(baseSnaps.sorted(by: snapRelevanceSort).prefix(18))
        }
        if zoom > 0.065 {
            return Array(baseSnaps.sorted(by: snapRelevanceSort).prefix(40))
        }
        return baseSnaps
    }

    private func snapRelevanceSort(_ lhs: LiveSnap, _ rhs: LiveSnap) -> Bool {
        if lhs.likesCount != rhs.likesCount {
            return lhs.likesCount > rhs.likesCount
        }
        return lhs.id > rhs.id
    }

    private var carouselSnaps: [LiveSnap] {
        let zoom = currentMapRegion.span.longitudeDelta
        guard zoom < 0.015 else { return [] }

        return visibleSnaps.filter { snap in
            let latDelta = abs(snap.coordinate.latitude - currentMapRegion.center.latitude)
            let lonDelta = abs(snap.coordinate.longitude - currentMapRegion.center.longitude)
            return latDelta <= currentMapRegion.span.latitudeDelta / 2.0 &&
                   lonDelta <= currentMapRegion.span.longitudeDelta / 2.0
        }
    }

    var body: some View {
        Group {
            if authManager.isLoading && !authManager.isSignedIn {
                LoadingBrandView()
            } else if !authManager.isSignedIn {
                AuthView(authManager: authManager)
            } else if authManager.profile == nil {
                ProfileOnboardingView(authManager: authManager)
            } else {
                mainApp
            }
        }
        .task {
            authManager.start()
            checkStreak()
        }
        .onChange(of: authManager.currentUserID) { _, userID in
            if userID == nil {
                snapMapViewModel.reset()
                eventViewModel.stopRealtime()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkStreak()
            }
        }
        .fullScreenCover(item: $fullScreenProfile) { explorer in
            ProfileSheetView(
                explorer: explorer,
                currentExplorer: currentExplorer,
                currentProfile: authManager.profile,
                snaps: snapMapViewModel.snaps.filter { $0.creator.id == explorer.id },
                events: eventViewModel.events,
                joinedEventIDs: eventViewModel.joinedEventIDs,
                onMessage: { activeSheet = .directMessage(explorer) },
                onOpenProfile: { selectedExplorer in
                    fullScreenProfile = selectedExplorer
                },
                onRefreshProfile: { await authManager.refreshProfile() },
                onLogout: explorer.id == currentExplorer.id ? {
                    fullScreenProfile = nil
                    Task {
                        await authManager.logout()
                    }
                } : nil,
                onDismiss: {
                    fullScreenProfile = nil
                }
            )
        }
    }

    private var currentExplorer: Explorer {
        authManager.profile?.explorer ?? LiveData.me
    }

    private func checkStreak() {
        let now = Date()
        let calendar = Calendar.current

        if lastAppOpenDate == 0 {
            streakCount = 1
            lastAppOpenDate = now.timeIntervalSince1970
            return
        }

        let lastDate = Date(timeIntervalSince1970: lastAppOpenDate)

        if calendar.isDateInToday(lastDate) {
            return
        } else if calendar.isDateInYesterday(lastDate) {
            streakCount += 1
            lastAppOpenDate = now.timeIntervalSince1970
        } else {
            streakCount = 1
            lastAppOpenDate = now.timeIntervalSince1970
        }
    }

    private var mainApp: some View {
        ZStack {
            background

            Group {
                switch selectedTab {
                case .events:
                    HomeEventsView(
                        events: eventViewModel.events,
                        joinedEventIDs: eventViewModel.joinedEventIDs,
                        radius: $eventRadius,
                        userCoordinate: locationStore.currentCoordinate,
                        currentUserID: authManager.currentUserID?.uuidString,
                        statusMessage: eventViewModel.statusMessage,
                        onCreateEvent: { activeSheet = .createEvent },
                        onOpenDetail: { activeSheet = .event($0) },
                        onRoute: route,
                        onToggleJoin: toggleJoin
                    )
                case .map:
                    ZStack(alignment: .bottom) {
                        SnapMapView(
                            snaps: visibleSnaps,
                            events: eventViewModel.events,
                            joinedEventIDs: eventViewModel.joinedEventIDs,
                            mapMode: $mapMode,
                            radius: $eventRadius,
                            isLoading: snapMapViewModel.isLoading,
                            statusMessage: snapMapViewModel.statusMessage,
                            cameraPosition: $cameraPosition,
                            mapRegion: currentMapRegion,
                            userCoordinate: locationStore.currentCoordinate,
                            locationStatus: locationStore.statusText,
                            onRequestLocation: centerOnUser,
                            onZoomIn: { zoomMap(by: 0.55) },
                            onZoomOut: { zoomMap(by: 1.55) },
                            onMapRegionChange: { currentMapRegion = $0 },
                            onSelectSnap: { activeSheet = .snap($0) },
                            onSelectEvent: { activeSheet = .event($0) }
                        )
                        .ignoresSafeArea()

                        let carousel = carouselSnaps
                        if carousel.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(carousel) { snap in
                                        Button {
                                            activeSheet = .snap(snap)
                                        } label: {
                                            SnapImageFrame(snap: snap, height: 160, iconSize: 40, iconFontSize: 24)
                                                .frame(width: 140)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
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
                    streakCount: streakCount,
                    onStreaks: { activeSheet = .streaks },
                    onGroups: { activeSheet = .groups },
                    onSearch: { activeSheet = .search },
                    onProfile: { fullScreenProfile = currentExplorer }
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
            await snapMapViewModel.loadSnaps()
            snapMapViewModel.startRealtime()
            await eventViewModel.loadEvents(currentUserID: authManager.currentUserID)
            eventViewModel.startRealtime(currentUserID: authManager.currentUserID)
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
                    authManager: authManager,
                    snapMapViewModel: snapMapViewModel,
                    locationStore: locationStore,
                    joinedEvents: eventViewModel.joinedEvents,
                    onPosted: {
                        activeSheet = nil
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            selectedTab = .map
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .createEvent:
                EventCreateView(
                    currentProfile: authManager.profile,
                    locationStore: locationStore,
                    eventViewModel: eventViewModel,
                    onCreated: { event in
                        activeSheet = .event(event)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .snap(let snap):
                SnapDetailView(
                    initialSnap: snap,
                    attachedEvent: eventViewModel.events.first { $0.id == snap.attachedEventID },
                    isOwner: snap.creator.id == currentExplorer.id,
                    onRoute: route,
                    onProfile: { fullScreenProfile = snap.creator },
                    onReport: {},
                    onDelete: {},
                    onSnapUpdated: { updatedSnap in snapMapViewModel.upsert(updatedSnap) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .event(let event):
                EventDetailView(
                    event: event,
                    isJoined: eventViewModel.joinedEventIDs.contains(event.id),
                    isHost: event.host.id == currentExplorer.id || event.hostID == currentExplorer.id,
                    distanceMiles: event.distanceMiles(from: locationStore.currentCoordinate),
                    eventSnaps: snapMapViewModel.snaps.filter { $0.attachedEventID == event.id },
                    onJoin: { toggleJoin(event) },
                    onChat: { activeSheet = .eventChat(event) },
                    onRoute: { route(event) },
                    onHost: { fullScreenProfile = event.host },
                    onOpenSnaps: { activeSheet = .eventSnaps(event) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .eventSnaps(let event):
                EventSnapGalleryView(
                    event: event,
                    snaps: snapMapViewModel.snaps.filter { $0.attachedEventID == event.id },
                    currentUserID: authManager.currentUserID?.uuidString,
                    onOpenSnap: { snap in activeSheet = .snap(snap) },
                    onProfile: { explorer in fullScreenProfile = explorer }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .eventChat(let event):
                EventChatView(
                    event: event,
                    currentUserID: authManager.currentUserID,
                    isJoined: eventViewModel.joinedEventIDs.contains(event.id)
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .directMessage(let explorer):
                DirectMessageView(
                    targetExplorer: explorer,
                    currentUserID: authManager.currentUserID
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .search:
                SearchSheetView(
                    events: eventViewModel.events,
                    joinedEventIDs: eventViewModel.joinedEventIDs,
                    currentUserID: authManager.currentUserID?.uuidString,
                    onOpenDetail: { activeSheet = .event($0) },
                    onRoute: route,
                    onToggleJoin: toggleJoin
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .streaks:
                StreaksSheetView(streakCount: streakCount)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            case .groups:
                InboxView(
                    currentUserID: authManager.currentUserID,
                    onOpenDM: { activeSheet = .directMessage($0.explorer) }
                )
                    .presentationDetents([.large])
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
            .blur(radius: 8)
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
        Task {
            await eventViewModel.toggleJoin(event, currentUserID: authManager.currentUserID)
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

private struct LoadingBrandView: View {
    var body: some View {
        ZStack {
            BrandBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("L!V!N")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.liveSky, Color.liveLavender, Color.liveCoral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                ProgressView()
                    .tint(Color.liveInk)
            }
        }
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
                Menu {
                    Button(action: {}) { Label("Venture Score", systemImage: "sparkles") }
                        .disabled(true)
                    Button(action: onGroups) { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
                    Button(action: {}) { Label("About", systemImage: "info.circle") }
                        .disabled(true)
                    Button(action: {}) { Label("Privacy", systemImage: "hand.raised.fill") }
                        .disabled(true)
                    Button(action: {}) { Label("Terms of Use", systemImage: "doc.text.fill") }
                        .disabled(true)
                    Button(action: {}) { Label("Legal/Support", systemImage: "questionmark.circle") }
                        .disabled(true)
                } label: {
                    PixelIconTile(size: 38, fill: Color.liveSurfaceElevated.opacity(0.86)) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.liveInk)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                }
                .accessibilityLabel("Menu")

                PixelIconButton(label: "Streaks", content: {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.liveInk)
                }, action: onStreaks)
                .overlay(alignment: .topTrailing) {
                    Text("\(max(1, streakCount))")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.liveInk)
                        .frame(width: 18, height: 18)
                        .background(Color.liveLemon, in: RoundedRectangle(cornerRadius: 5))
                        .offset(x: 4, y: -4)
                }

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
    @Binding var radius: EventRadius
    let userCoordinate: CLLocationCoordinate2D?
    let currentUserID: String?
    let statusMessage: String?
    let onCreateEvent: () -> Void
    let onOpenDetail: (LiveEvent) -> Void
    let onRoute: (LiveEvent) -> Void
    let onToggleJoin: (LiveEvent) -> Void

    @State private var expandedEntryID: String?
    @State private var tapHaptic = UISelectionFeedbackGenerator()
    @State private var scrollHaptic = UISelectionFeedbackGenerator()

    private var visibleEvents: [LiveEvent] {
        guard !events.isEmpty else { return [] }
        let filtered = events.filter { event in
            guard event.isVisibleInPublicSurfaces else { return false }
            guard let miles = radius.miles, let distance = event.distanceMiles(from: userCoordinate) else {
                return true
            }
            return distance <= miles
        }
        return Array(filtered.prefix(20))
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
                            currentUserID: currentUserID,
                            isShowingDetails: expandedEntryID == entry.id,
                            onToggleDetails: {
                                tapHaptic.selectionChanged()
                                tapHaptic.prepare()
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                    expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                                }
                            },
                            onOpenDetail: { onOpenDetail(entry.event) },
                            onRoute: { onRoute(entry.event) },
                            onToggleJoin: { onToggleJoin(entry.event) },
                            onReport: {},
                            onEdit: {}
                        )
                        .id(entry.id)
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: -12)),
                            removal: .opacity
                        ))
                    }

                    if eventEntries.isEmpty {
                        EmptyStateBlock(
                            symbolName: "scope",
                            title: "No events nearby",
                            message: "Try a wider radius or create the first L!V!N event around you."
                        )
                        .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 176)
                .padding(.bottom, 150)
            }
            .onScrollGeometryChange(for: Int.self) { geometry in
                Int(max(0, geometry.contentOffset.y) / 82)
            } action: { oldTick, newTick in
                guard oldTick != newTick else { return }
                scrollHaptic.selectionChanged()
                scrollHaptic.prepare()
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    RadiusPicker(selection: $radius)

                    Button(action: onCreateEvent) {
                        Label("Event", systemImage: "plus")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveOnInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create event")
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 104)
        }
        .background(BrandBackdrop().blur(radius: 8))
        .onAppear {
            tapHaptic.prepare()
            scrollHaptic.prepare()
        }
    }
}

private struct RadiusPicker: View {
    @Binding var selection: EventRadius
    @State private var haptic = UISelectionFeedbackGenerator()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EventRadius.allCases) { radius in
                    Button {
                        haptic.selectionChanged()
                        haptic.prepare()
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            selection = radius
                        }
                    } label: {
                        Text(radius.rawValue)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(selection == radius ? Color.liveOnInk : Color.liveInk)
                            .frame(width: 58, height: 32)
                            .background(
                                selection == radius ? AnyShapeStyle(Color.liveInk) : AnyShapeStyle(Color.liveSurfaceElevated),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.liveStroke, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 1)
            .padding(.horizontal, 4)
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(width: (58 * 4) + (6 * 3) + 8) // Exactly fits 4 options visible at once
        .onScrollGeometryChange(for: Int.self) { geometry in
            Int(max(0, geometry.contentOffset.x) / 30)
        } action: { oldTick, newTick in
            guard oldTick != newTick else { return }
            haptic.selectionChanged()
            haptic.prepare()
        }
    }
}

private struct EmptyStateBlock: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            PixelIconTile(size: 54, fill: Color.liveSurfaceElevated.opacity(0.82)) {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.liveInk)
            }

            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            Text(message)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
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
    let currentUserID: String?
    let isShowingDetails: Bool
    let onToggleDetails: () -> Void
    let onOpenDetail: () -> Void
    let onRoute: () -> Void
    let onToggleJoin: () -> Void
    let onReport: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            EventFrontCard(event: event, isJoined: isJoined, onFlip: onToggleDetails)
                .opacity(isShowingDetails ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingDetails ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .allowsHitTesting(!isShowingDetails)
                .accessibilityHidden(isShowingDetails)

            EventBackCard(
                event: event,
                isJoined: isJoined,
                isCreator: event.host.id == currentUserID,
                onFlip: onToggleDetails,
                onRoute: onRoute,
                onToggleJoin: onToggleJoin,
                onReport: onReport,
                onEdit: onEdit
            )
            .opacity(isShowingDetails ? 1 : 0)
            .rotation3DEffect(
                .degrees(isShowingDetails ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
            .allowsHitTesting(isShowingDetails)
            .accessibilityHidden(!isShowingDetails)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingDetails)
    }
}

private struct LinePatternView: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            let numLines = Int((size.width + size.height) / step)
            for i in 0..<numLines {
                var path = Path()
                let xOffset = CGFloat(i) * step
                path.move(to: CGPoint(x: xOffset, y: 0))
                path.addLine(to: CGPoint(x: xOffset - size.height, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 0.7)
            }
        }
        .opacity(0.04)
    }
}

private struct EventFrontCard: View {
    let event: LiveEvent
    let isJoined: Bool
    let onFlip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                if let imageURL = event.coverImageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(Color.liveInk)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(event.palette.gradient)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .aspectRatio(1.0, contentMode: .fill)
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    if isJoined {
                        Text("Signed In")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.liveMint.opacity(0.12), in: Capsule())
                    } else {
                        Text("Sign Up")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.liveInk.opacity(0.05), in: Capsule())
                    }
                }

                HStack(spacing: 12) {
                    CompactMeta(symbolName: "clock.fill", text: event.timeLabel, color: Color.liveMuted)
                    CompactMeta(symbolName: "person.2.fill", text: "\(event.attendeeCount) going", color: Color.liveMuted)
                    CompactMeta(symbolName: "mappin.circle.fill", text: event.locationName, color: Color.liveMuted)
                }
            }
            .padding(16)
            .background(Color.liveSurface)
        }
        .background(Color.liveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.liveInk.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onFlip()
        }
    }

    private var placeholderView: some View {
        ZStack {
            event.palette.gradient

            Image(systemName: event.palette.symbolName)
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(Color.liveOnInk.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct EventBackCard: View {
    let event: LiveEvent
    let isJoined: Bool
    let isCreator: Bool
    let onFlip: () -> Void
    let onRoute: () -> Void
    let onToggleJoin: () -> Void
    let onReport: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Text(event.title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Spacer()

                Button(action: onFlip) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.liveInk)
                        .frame(width: 34, height: 34)
                        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show event front")
            }

            VStack(alignment: .leading, spacing: 10) {
                Label(event.locationName, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveInk)

                Label("\(event.attendeeCount) going", systemImage: "person.2.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveMint)
            }

            HStack {
                ExplorerAvatar(explorer: event.host, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.host.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                    Text("Host")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 12))

            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: onToggleJoin) {
                        Label(isJoined ? "Signed Up" : "Sign Up", systemImage: isJoined ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(isJoined ? Color.liveMint : Color.liveInk, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: onRoute) {
                        Label("Route", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                if isCreator {
                    Button(action: onEdit) {
                        Label("Edit Event", systemImage: "pencil")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.liveLemon, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onReport) {
                        Text("Report")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveAlertRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.liveAlertRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.liveSurface
                .overlay(LinePatternView(color: Color.liveInk))
                .overlay(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.liveInk.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onFlip()
        }
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
    var color: Color = .liveInk

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(color)

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.78))
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
    var customImage: UIImage? = nil

    var body: some View {
        ZStack {
            if let customImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
            } else if let imageURL = event.coverImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(Color.liveInk)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(event.palette.gradient)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(event.palette.gradient)

            PixelIconTile(size: 58, fill: Color.white.opacity(0.18)) {
                Image(systemName: event.palette.symbolName)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color.liveInk)
            }
        }
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
    let events: [LiveEvent]
    let joinedEventIDs: Set<String>
    @Binding var mapMode: MapMode
    @Binding var radius: EventRadius
    let isLoading: Bool
    let statusMessage: String?
    @Binding var cameraPosition: MapCameraPosition
    let mapRegion: MKCoordinateRegion
    let userCoordinate: CLLocationCoordinate2D?
    let locationStatus: String
    let onRequestLocation: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onMapRegionChange: (MKCoordinateRegion) -> Void
    let onSelectSnap: (LiveSnap) -> Void
    let onSelectEvent: (LiveEvent) -> Void

    private var visibleEvents: [LiveEvent] {
        guard mapMode == .public else { return [] }
        let zoom = mapRegion.span.longitudeDelta
        let limit: Int
        if zoom > 8 {
            limit = 4
        } else if zoom > 3 {
            limit = 8
        } else if zoom > 1 {
            limit = 14
        } else {
            limit = 28
        }

        return events.filter { event in
            guard event.isVisibleInPublicSurfaces else { return false }
            guard let miles = radius.miles, let userCoordinate, let distance = event.distanceMiles(from: userCoordinate) else {
                return true
            }
            return distance <= miles
        }
        .filter { event in
            let latDelta = abs(event.coordinate.latitude - mapRegion.center.latitude)
            let lonDelta = abs(event.coordinate.longitude - mapRegion.center.longitude)
            return latDelta <= mapRegion.span.latitudeDelta / 1.7
                && lonDelta <= mapRegion.span.longitudeDelta / 1.7
        }
        .sorted { lhs, rhs in
            if lhs.isSignedUp != rhs.isSignedUp { return lhs.isSignedUp && !rhs.isSignedUp }
            return (lhs.startsAt ?? .distantPast) > (rhs.startsAt ?? .distantPast)
        }
        .prefix(limit)
        .map { $0 }
    }

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            UserAnnotation()

            ForEach(visibleEvents) { event in
                Annotation(event.title, coordinate: event.coordinate, anchor: .bottom) {
                    Button {
                        onSelectEvent(event)
                    } label: {
                        EventMapPin(event: event, isJoined: joinedEventIDs.contains(event.id))
                    }
                    .buttonStyle(.plain)
                }
            }

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
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                Picker("Map mode", selection: $mapMode) {
                    ForEach(MapMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                if mapMode == .public {
                    RadiusPicker(selection: $radius)
                        .frame(maxWidth: 315)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 112)
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
        .overlay(alignment: .bottom) {
            if snaps.isEmpty && !isLoading {
                HStack(spacing: 8) {
                    Image(systemName: mapMode == .personal ? "person.crop.square.filled.and.at.rectangle" : "map")
                        .font(.system(size: 13, weight: .black))

                    Text(mapMode == .personal ? "Your personal map is waiting for your first snap." : "No public snaps nearby yet.")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color.liveInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.liveStroke, lineWidth: 1)
                }
                .padding(.bottom, 92)
            } else if isLoading || statusMessage != nil {
                HStack(spacing: 9) {
                    if isLoading {
                        ProgressView()
                            .tint(Color.liveInk)
                    }

                    Text(statusMessage ?? "Loading live snaps...")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.liveStroke, lineWidth: 1)
                }
                .padding(.bottom, 92)
            }
        }
    }
}

private struct EventMapPin: View {
    let event: LiveEvent
    let isJoined: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                EventPoster(event: event)
                    .frame(width: 76, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: event.palette.primary.opacity(0.3), radius: 16, y: 9)

                Image(systemName: isJoined ? "checkmark.circle.fill" : LiveEventCategory(label: event.category).symbolName)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.liveOnInk)
                    .frame(width: 24, height: 24)
                    .background(isJoined ? Color.liveMint : Color.liveInk.opacity(0.86), in: Circle())
                    .offset(x: 7, y: -7)
            }

            Text(event.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)
                .lineLimit(1)
                .frame(maxWidth: 104)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("\(event.title) event")
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
            SnapImageFrame(snap: snap, height: 78, iconSize: 42, iconFontSize: 22)
                .frame(width: 66, height: 78)
                .shadow(color: snap.palette.primary.opacity(0.3), radius: 16, y: 9)

            if snap.imageCount > 1 {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.liveInk)
                    .frame(width: 28, height: 28)
                    .background(Color.liveSurfaceElevated, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.liveStroke, lineWidth: 1)
                    }
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

private struct SnapImageFrame: View {
    let snap: LiveSnap
    let height: CGFloat
    let iconSize: CGFloat
    let iconFontSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(snap.palette.gradient)

            if let imageURL = snap.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(Color.liveInk)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white, lineWidth: 3)
        }
        .overlay {
            PixelCornerMarks()
                .stroke(Color.white.opacity(0.52), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                .padding(7)
        }
    }

    private var placeholder: some View {
        PixelIconTile(size: iconSize, fill: Color.white.opacity(0.16)) {
            Image(systemName: snap.palette.symbolName)
                .font(.system(size: iconFontSize, weight: .black))
                .foregroundStyle(Color.liveInk)
        }
    }
}

private struct SnapDetailView: View {
    let initialSnap: LiveSnap
    let attachedEvent: LiveEvent?
    let isOwner: Bool
    let onRoute: (LiveEvent) -> Void
    let onProfile: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void
    let onSnapUpdated: (LiveSnap) -> Void

    @State private var snap: LiveSnap
    @State private var comments: [(SnapComment, Profile?)] = []
    @State private var newComment: String = ""
    @State private var isLiking = false
    @State private var isPostingComment = false
    private let snapService = SnapService()

    init(
        initialSnap: LiveSnap,
        attachedEvent: LiveEvent?,
        isOwner: Bool,
        onRoute: @escaping (LiveEvent) -> Void,
        onProfile: @escaping () -> Void,
        onReport: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSnapUpdated: @escaping (LiveSnap) -> Void
    ) {
        self.initialSnap = initialSnap
        self.attachedEvent = attachedEvent
        self.isOwner = isOwner
        self.onRoute = onRoute
        self.onProfile = onProfile
        self.onReport = onReport
        self.onDelete = onDelete
        self.onSnapUpdated = onSnapUpdated
        self._snap = State(initialValue: initialSnap)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                ZStack(alignment: .topTrailing) {
                    SnapImageFrame(snap: snap, height: 290, iconSize: 112, iconFontSize: 62)

                    if snap.imageCount > 1 {
                        Label("\(snap.imageCount)", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.liveInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.liveSurfaceElevated.opacity(0.92), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.liveStroke, lineWidth: 1)
                            }
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

                HStack(spacing: 9) {
                    Button(action: toggleLike) {
                        HStack(spacing: 6) {
                            Image(systemName: snap.hasLiked ? "heart.fill" : "heart")
                            Text("\(snap.likesCount)")
                        }
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(snap.hasLiked ? Color.liveCoral : Color.liveInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLiking)

                    Button(action: onReport) {
                        Label("Report", systemImage: "flag.fill")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if isOwner {
                        Button(action: onDelete) {
                            Label("Delete", systemImage: "trash.fill")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.liveAlertRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !comments.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Comments (\(snap.commentsCount))")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        ForEach(comments, id: \.0.id) { comment, profile in
                            HStack(alignment: .top, spacing: 8) {
                                ExplorerAvatar(explorer: profile?.explorer ?? Explorer(id: "", handle: "Unknown", displayName: "Unknown", bio: "", avatarSymbolName: "person.fill", ventureScore: 0, streak: 0, followers: 0, following: 0), size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile?.handle ?? "Unknown")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                    Text(comment.body)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.liveMuted)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(12)
                        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 24))

                    if !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: postComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.liveInk)
                        }
                        .disabled(isPostingComment)
                    }
                }
                .padding(.top, 4)

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
                                    .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.liveStroke, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
        .background(Color.liveCanvas)
        .task {
            await loadComments()
        }
    }

    private func toggleLike() {
        guard !isLiking else { return }
        isLiking = true
        let newValue = !snap.hasLiked

        snap.hasLiked = newValue
        snap.likesCount += newValue ? 1 : -1
        onSnapUpdated(snap)

        Task {
            do {
                try await snapService.toggleLike(snapID: snap.id, isLiked: newValue)
            } catch {
                snap.hasLiked = !newValue
                snap.likesCount += !newValue ? 1 : -1
                onSnapUpdated(snap)
            }
            isLiking = false
        }
    }

    private func loadComments() async {
        do {
            comments = try await snapService.fetchComments(snapID: snap.id)
            snap.commentsCount = comments.count
            onSnapUpdated(snap)
        } catch {
            print("Failed to load comments: \(error)")
        }
    }

    private func postComment() {
        guard !isPostingComment else { return }
        isPostingComment = true
        let body = newComment.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                try await snapService.postComment(snapID: snap.id, body: body)
                newComment = ""
                await loadComments()
            } catch {
                print("Failed to post comment: \(error)")
            }
            isPostingComment = false
        }
    }
}

private struct LocationSearchRow: View {
    @ObservedObject var locationSearch: LocationSearchService
    @Binding var locationName: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search for a place...", text: $locationSearch.searchQuery)
                .liveFieldStyle()
                .onChange(of: locationSearch.searchQuery) { _, query in
                    locationName = query
                    selectedCoordinate = nil
                }

            if !locationSearch.completions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(locationSearch.completions.enumerated()), id: \.offset) { _, completion in
                        Button {
                            locationName = completion.title
                            locationSearch.searchQuery = completion.title
                            locationSearch.completions = []
                            Task {
                                if let mapItem = try? await locationSearch.search(for: completion) {
                                    guard locationSearch.searchQuery == completion.title else { return }
                                    selectedCoordinate = mapItem.placemark.coordinate
                                }
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(completion.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.liveInk)
                                Text(completion.subtitle)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.liveMuted)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct EventCreateView: View {
    let currentProfile: Profile?
    @ObservedObject var locationStore: LocationStore
    @ObservedObject var eventViewModel: EventViewModel
    let onCreated: (LiveEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationSearch = LocationSearchService()

    @State private var title = ""
    @State private var categoryQuery = ""
    @State private var selectedCategory: LiveEventCategory?
    @State private var otherCategory = ""
    @State private var details = ""
    @State private var locationName = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var startsAt = Date().addingTimeInterval(60 * 60)
    @State private var endsAt = Date().addingTimeInterval(2 * 60 * 60)
    @State private var selectedCapacity: Int?
    @State private var isPublic = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var customImage: UIImage?

    private let capacityOptions = [6, 10, 15, 20, 30, 50, 100]

    private var filteredCategories: [LiveEventCategory] {
        let query = categoryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return LiveEventCategory.allCases }
        return LiveEventCategory.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(query) }
    }

    private var categoryValue: String {
        guard let selectedCategory else { return "" }
        if selectedCategory == .other {
            return otherCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedCategory.rawValue
    }

    private var selectedPrompt: String {
        (selectedCategory ?? .social).descriptionPrompt
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackdrop()
                    .blur(radius: 10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        coverPicker
                        titleSection
                        categorySection

                        if selectedCategory != nil {
                            descriptionSection
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        timeSection
                        locationSection
                        capacitySection
                        privacySection

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.liveAlertRed)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.liveSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            Task { await createEvent() }
                        } label: {
                            HStack(spacing: 9) {
                                if isSaving {
                                    ProgressView()
                                        .tint(Color.liveOnInk)
                                }
                                Text(isSaving ? "Publishing..." : "Publish Event")
                            }
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveOnInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.liveLavender.opacity(0.28), radius: 18, y: 10)
                        }
                        .disabled(isSaving)
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.liveInk)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: selectedImageItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                    customImage = uiImage
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Create a reason to meet up")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)
            Text("Make it clear, visual, and easy for people to say yes.")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $selectedImageItem, matching: .images) {
            EventPoster(event: previewEvent, customImage: customImage)
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 9) {
                        Image(systemName: "camera.fill")
                        Text(customImage == nil ? "Add event cover" : "Change cover")
                    }
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.38), in: Capsule())
                    .padding(14)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.16), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
    }

    private var titleSection: some View {
        formField("Event title") {
            TextField("Pickup volleyball, Bible study, coffee crawl", text: $title)
                .liveFieldStyle()
        }
    }

    private var categorySection: some View {
        formField("Category") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.liveMuted)
                    TextField("Search Social, Basketball, Hiking…", text: $categoryQuery)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .textInputAutocapitalization(.words)
                }
                .padding(12)
                .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 14))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(filteredCategories) { category in
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    selectedCategory = category
                                    categoryQuery = category.rawValue
                                    if category != .other {
                                        otherCategory = ""
                                    }
                                }
                            } label: {
                                Label(category.rawValue, systemImage: category.symbolName)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(selectedCategory == category ? Color.liveOnInk : Color.liveInk)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selectedCategory == category ? Color.liveInk : Color.liveSurface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if selectedCategory == .other {
                    TextField("Other category", text: $otherCategory)
                        .liveFieldStyle()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var descriptionSection: some View {
        formField("Description / what to bring") {
            TextEditor(text: $details)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.liveInk)
                .frame(minHeight: 118)
                .padding(10)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if details.isEmpty {
                        Text(selectedPrompt)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.liveMuted.opacity(0.72))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date & time")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            VStack(spacing: 10) {
                DatePicker("Starts", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Ends", selection: $endsAt, in: startsAt..., displayedComponents: [.date, .hourAndMinute])
            }
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Color.liveInk)
            .padding(13)
            .background(Color.liveSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var locationSection: some View {
        formField("Location") {
            VStack(alignment: .leading, spacing: 8) {
                LocationSearchRow(
                    locationSearch: locationSearch,
                    locationName: $locationName,
                    selectedCoordinate: $selectedCoordinate
                )
                Text(selectedCoordinate == nil ? "Choose a suggested place so LIVE can save the exact pin." : "Exact pin selected.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedCoordinate == nil ? Color.liveMuted : Color.liveMint)
            }
        }
    }

    private var capacitySection: some View {
        formField("Capacity") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    capacityButton(title: "Unlimited", value: nil)
                    ForEach(capacityOptions, id: \.self) { value in
                        capacityButton(title: "\(value)", value: value)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var privacySection: some View {
        formField("Visibility") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    visibilityButton(title: "Public", subtitle: "Shows in Events + Map", symbolName: "globe.americas.fill", value: true)
                    visibilityButton(title: "Private", subtitle: "Host/members only", symbolName: "lock.fill", value: false)
                }
                if !isPublic {
                    Label("Private invite tokens will be saved. Share links need a future deep-link/RPC pass before they are shown.", systemImage: "link")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                        .padding(11)
                        .background(Color.liveSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var previewEvent: LiveEvent {
        LiveEvent(
            id: "preview",
            title: title.isEmpty ? "New L!V!N Event" : title,
            host: currentProfile?.explorer ?? LiveData.me,
            category: categoryValue.isEmpty ? "Social" : categoryValue,
            locationName: locationName.isEmpty ? "Your location" : locationName,
            timeLabel: "Soon",
            attendeeCount: 1,
            priceLabel: "Free",
            details: details.isEmpty ? "Add enough detail so people know what they are walking into." : details,
            coordinate: selectedCoordinate ?? locationStore.displayCoordinate,
            palette: LiveEventCategory(label: categoryValue).palette,
            isSignedUp: true,
            pulse: .fresh,
            hostID: currentProfile?.id.uuidString,
            startsAt: startsAt,
            endsAt: endsAt,
            capacity: selectedCapacity,
            isPublic: isPublic
        )
    }

    private func formField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)
            content()
        }
    }

    private func capacityButton(title: String, value: Int?) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedCapacity = value
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(selectedCapacity == value ? Color.liveOnInk : Color.liveInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selectedCapacity == value ? Color.liveInk : Color.liveSurface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func visibilityButton(title: String, subtitle: String, symbolName: String, value: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isPublic = value
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .black))
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isPublic == value ? Color.liveOnInk.opacity(0.72) : Color.liveMuted)
                    .lineLimit(2)
            }
            .foregroundStyle(isPublic == value ? Color.liveOnInk : Color.liveInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(isPublic == value ? Color.liveInk : Color.liveSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func createEvent() async {
        errorMessage = nil
        guard let currentProfile else {
            errorMessage = "Log in before creating an event."
            return
        }
        guard let selectedCategory else {
            errorMessage = "Choose an event category."
            return
        }
        let cleanCategory = categoryValue
        guard !cleanCategory.isEmpty else {
            errorMessage = selectedCategory == .other ? "Add your custom category." : "Choose an event category."
            return
        }
        guard endsAt > startsAt else {
            errorMessage = "End time must be after the start time."
            return
        }
        guard let coordinate = selectedCoordinate else {
            errorMessage = "Choose a suggested address/place so LIVE can save the exact location."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let draft = EventDraft(
                title: title,
                category: cleanCategory,
                details: details,
                startsAt: startsAt,
                endsAt: endsAt,
                locationName: locationName,
                coordinate: coordinate,
                capacity: selectedCapacity,
                image: customImage,
                isPublic: isPublic
            )
            let event = try await eventViewModel.createEvent(draft: draft, hostProfile: currentProfile)
            onCreated(event)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct EventDetailView: View {
    let event: LiveEvent
    let isJoined: Bool
    let isHost: Bool
    let distanceMiles: Double?
    let eventSnaps: [LiveSnap]
    let onJoin: () -> Void
    let onChat: () -> Void
    let onRoute: () -> Void
    let onHost: () -> Void
    let onOpenSnaps: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                ZStack(alignment: .bottomLeading) {
                    EventPoster(event: event)
                        .frame(maxWidth: .infinity)
                        .frame(height: 235)

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.66)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            EventBadge(text: event.category, color: event.palette.primary)
                            if !event.isPublic {
                                EventBadge(text: "Private", color: Color.liveLavender)
                            }
                            Spacer()
                            Button(action: onChat) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(isJoined ? Color.liveOnInk : Color.white.opacity(0.44))
                                    .frame(width: 42, height: 42)
                                    .background(isJoined ? event.palette.primary : Color.black.opacity(0.24), in: Circle())
                            }
                            .disabled(!isJoined)
                            .buttonStyle(.plain)
                            .accessibilityLabel(isJoined ? "Open event chat" : "Join to unlock event chat")
                        }

                        Text(event.title)
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.16), radius: 22, y: 12)

                HStack(alignment: .center, spacing: 11) {
                    Button(action: onHost) {
                        HStack(spacing: 9) {
                            ExplorerAvatar(explorer: event.host, size: 38)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Created by")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.liveMuted)
                                Text(event.host.handle)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)
                            }
                        }
                        .padding(10)
                        .background(Color.liveSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let capacity = event.capacity {
                        EventBadge(text: "\(event.attendeeCount)/\(capacity)", color: Color.liveLemon)
                    } else {
                        EventBadge(text: "\(event.attendeeCount) joined", color: Color.liveMint)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                    Text(event.details.isEmpty ? "No description yet." : event.details)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.liveSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 10) {
                    Label(event.locationName, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)

                    HStack(spacing: 8) {
                        DetailPill(symbolName: "clock.fill", text: event.dateTimeSummary)
                        DetailPill(symbolName: "person.2.fill", text: "\(event.attendeeCount) joined")
                        if let distanceMiles {
                            DetailPill(symbolName: "location.fill", text: String(format: "%.1f mi", distanceMiles))
                        }
                    }
                }
                .padding(14)
                .background(Color.liveSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))

                Map(position: .constant(.region(MKCoordinateRegion(
                    center: event.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
                )))) {
                    Annotation(event.title, coordinate: event.coordinate) {
                        EventMapPin(event: event, isJoined: isJoined)
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 178)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(true)

                HStack(spacing: 8) {
                    Button(action: onJoin) {
                        Label(isJoined ? "Joined" : "Sign Up", systemImage: isJoined ? "checkmark.circle.fill" : "plus.circle.fill")
                            .liveActionButton(fill: isJoined ? Color.liveMint.opacity(0.35) : Color.liveInk, foreground: isJoined ? Color.liveInk : Color.liveOnInk)
                    }
                    .buttonStyle(.plain)

                    Button(action: onRoute) {
                        Label("Route", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .liveActionButton(fill: Color.liveSurfaceElevated, foreground: Color.liveInk)
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenSnaps) {
                        Label(eventSnaps.isEmpty ? "Snaps" : "Snaps \(eventSnaps.count)", systemImage: "photo.stack.fill")
                            .liveActionButton(fill: eventSnaps.isEmpty ? Color.liveSurface : Color.liveLavender.opacity(0.34), foreground: Color.liveInk)
                    }
                    .disabled(eventSnaps.isEmpty)
                    .buttonStyle(.plain)
                }

                if !event.isPublic {
                    Label("Private event share links are not active yet. Invite token is saved for the backend deep-link flow.", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                        .padding(12)
                        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 14))
                }

                if isHost {
                    Button {} label: {
                        Label("Edit Event", systemImage: "pencil")
                            .liveActionButton(fill: Color.liveSurface, foreground: Color.liveInk)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {} label: {
                        Label("Report", systemImage: "flag.fill")
                            .liveActionButton(fill: Color.liveSurface, foreground: Color.liveAlertRed)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(BrandBackdrop().blur(radius: 8))
    }
}

private struct EventChatView: View {
    let event: LiveEvent
    let currentUserID: UUID?
    let isJoined: Bool

    @StateObject private var viewModel = EventChatViewModel()
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let eventID = UUID(uuidString: event.id), isJoined {
                    chatContent(eventID: eventID)
                } else {
                    EmptyStateBlock(
                        symbolName: "bubble.left.and.bubble.right.fill",
                        title: isJoined ? "Chat opens for real events" : "Join the event first",
                        message: isJoined ? "Local preview events do not have a Supabase chat room yet." : "After joining, the event group chat unlocks here."
                    )
                    .padding(18)
                    Spacer()
                }
            }
            .background(Color.liveCanvas)
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func chatContent(eventID: UUID) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color.liveInk)
                            .padding(.vertical, 32)
                    } else if viewModel.messages.isEmpty {
                        EmptyStateBlock(
                            symbolName: "bubble.left.fill",
                            title: "No messages yet",
                            message: "Say the first thing and make the event feel alive."
                        )
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                }
                .padding(16)
            }

            if let error = viewModel.errorMessage ?? viewModel.realtimeWarning {
                Text(error)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveAlertRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 9) {
                TextField("Message the event", text: $messageText)
                    .liveFieldStyle()

                Button {
                    let body = messageText
                    messageText = ""
                    Task {
                        await viewModel.send(eventID: eventID, currentUserID: currentUserID, body: body)
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.liveOnInk)
                        .frame(width: 42, height: 42)
                        .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
        .task {
            await viewModel.load(eventID: eventID, currentUserID: currentUserID)
            viewModel.startRealtime(eventID: eventID, currentUserID: currentUserID)
        }
        .onDisappear {
            viewModel.stopRealtime()
        }
    }
}

private struct ChatBubble: View {
    let message: LiveChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine {
                Spacer(minLength: 40)
            } else {
                ExplorerAvatar(explorer: message.sender, size: 30)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if !message.isMine {
                    Text(message.sender.handle)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.liveMuted)
                }

                Text(message.body)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(message.isMine ? Color.liveOnInk : Color.liveInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(message.isMine ? Color.liveInk : Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(message.timeLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)
            }

            if !message.isMine {
                Spacer(minLength: 40)
            }
        }
    }
}

private struct EventSnapGalleryView: View {
    let event: LiveEvent
    let snaps: [LiveSnap]
    let currentUserID: String?
    let onOpenSnap: (LiveSnap) -> Void
    let onProfile: (Explorer) -> Void

    @State private var index = 0
    @State private var saveMessage: String?

    private var selectedSnap: LiveSnap? {
        guard snaps.indices.contains(index) else { return nil }
        return snaps[index]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomLeading) {
                        EventPoster(event: event)
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                        LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title)
                                .font(.system(size: 27, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text("\(snaps.count) event snap\(snaps.count == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if let selectedSnap {
                        HStack {
                            arrowButton(symbolName: "chevron.left", enabled: index > 0) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    index -= 1
                                }
                            }

                            Spacer()

                            Text("\(index + 1) / \(snaps.count)")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.liveMuted)

                            Spacer()

                            arrowButton(symbolName: "chevron.right", enabled: index < snaps.count - 1) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    index += 1
                                }
                            }
                        }

                        EventSnapGalleryCard(
                            snap: selectedSnap,
                            isOwner: selectedSnap.creator.id == currentUserID,
                            saveMessage: saveMessage,
                            onOpen: { onOpenSnap(selectedSnap) },
                            onProfile: { onProfile(selectedSnap.creator) },
                            onSave: { saveSnap(selectedSnap) }
                        )
                    } else {
                        EmptyStateBlock(
                            symbolName: "photo.stack.fill",
                            title: "No event snaps yet",
                            message: "Snaps attached to this event will live here after people post them."
                        )
                    }
                }
                .padding(18)
            }
            .background(BrandBackdrop().blur(radius: 8))
            .navigationTitle("Event Snaps")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: snaps.count) { _, count in
            if index >= count {
                index = max(0, count - 1)
            }
        }
    }

    private func arrowButton(symbolName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(enabled ? Color.liveInk : Color.liveMuted.opacity(0.45))
                .frame(width: 44, height: 44)
                .background(Color.liveSurface, in: Circle())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }

    private func saveSnap(_ snap: LiveSnap) {
        guard let imageURL = snap.imageURL else {
            saveMessage = "Image is still loading."
            return
        }

        saveMessage = "Saving..."
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                guard let image = UIImage(data: data) else {
                    saveMessage = "Could not read image."
                    return
                }
                UIImageWriteToSavedPhotosAlbum(image.liveWatermarked("@app.livin"), nil, nil, nil)
                saveMessage = "Saved to camera roll."
            } catch {
                saveMessage = "Save failed. Try again."
            }
        }
    }
}

private struct EventSnapGalleryCard: View {
    let snap: LiveSnap
    let isOwner: Bool
    let saveMessage: String?
    let onOpen: () -> Void
    let onProfile: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(snap.title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)
                    .lineLimit(2)
                Spacer()
                if isOwner {
                    Button(action: onSave) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.liveInk)
                            .frame(width: 38, height: 38)
                            .background(Color.liveSurfaceElevated, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onProfile) {
                HStack(spacing: 8) {
                    ExplorerAvatar(explorer: snap.creator, size: 32)
                    Text(snap.creator.handle)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.liveSurfaceElevated, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                SnapImageFrame(snap: snap, height: 320, iconSize: 96, iconFontSize: 52)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Text(snap.caption)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
                .lineLimit(3)

            if let saveMessage {
                Text(saveMessage)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)
            }
        }
        .padding(16)
        .background(Color.liveSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CreateSnapView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var snapMapViewModel: SnapMapViewModel
    @ObservedObject var locationStore: LocationStore
    let joinedEvents: [LiveEvent]
    let onPosted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var locationName = ""
    @State private var isPartOfEvent = false
    @State private var selectedEventID: String?
    @State private var capturedImage: UIImage?
    @State private var isCameraPresented = false
    @State private var didAutoOpenCamera = false
    @State private var isPosting = false
    @State private var errorMessage: String?

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

                            Text("Share what's happening near you right now.")
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
                    }

                    LocationLockRow(locationStore: locationStore)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location name")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        TextField("Griffith Park, Venice Beach, Campus quad", text: $locationName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.liveInk)
                            .padding(13)
                            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.liveLavender.opacity(0.24), lineWidth: 1)
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Snap caption")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        TextEditor(text: $caption)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.liveInk)
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

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveAlertRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        Task {
                            await postSnap()
                        }
                    } label: {
                        HStack(spacing: 9) {
                            if isPosting {
                                ProgressView()
                                    .tint(Color.liveOnInk)
                            }

                            Text(isPosting ? "Posting..." : "Post live snap")
                        }
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveOnInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isPosting)
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
        .tint(Color.liveInk)
        .onAppear {
            locationStore.requestLocation()
            if capturedImage == nil, !didAutoOpenCamera {
                didAutoOpenCamera = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isCameraPresented = true
                }
            }
            if !isPartOfEvent {
                suggestEvent()
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraCaptureView(image: $capturedImage)
                .ignoresSafeArea()
        }
    }

    private func suggestEvent() {
        let currentLoc = CLLocation(latitude: locationStore.displayCoordinate.latitude, longitude: locationStore.displayCoordinate.longitude)
        let now = Date()

        if let nearby = joinedEvents.first(where: { event in
            let eventLoc = CLLocation(latitude: event.coordinate.latitude, longitude: event.coordinate.longitude)
            let distance = currentLoc.distance(from: eventLoc)
            guard let startsAt = event.startsAt else { return false }
            let isActive = now >= startsAt.addingTimeInterval(-3600) && (event.endsAt == nil || now <= event.endsAt!)
            return distance < 1000 && isActive
        }) {
            isPartOfEvent = true
            selectedEventID = nearby.id
        }
    }

    private func postSnap() async {
        errorMessage = nil
        locationStore.requestLocation()

        guard authManager.isSignedIn else {
            errorMessage = "Log in before posting a live snap."
            return
        }

        guard let capturedImage else {
            errorMessage = "Take a picture before posting."
            return
        }

        guard let coordinate = locationStore.currentCoordinate else {
            errorMessage = "Current location is required. Allow location access and try again."
            return
        }

        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCaption.isEmpty else {
            errorMessage = "Missing caption."
            return
        }

        let cleanLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLocationName.isEmpty else {
            errorMessage = "Missing location name."
            return
        }

        isPosting = true
        defer { isPosting = false }

        do {
            let draft = SnapDraft(
                image: capturedImage,
                caption: cleanCaption,
                locationName: cleanLocationName,
                coordinate: coordinate,
                attachedEventID: isPartOfEvent ? selectedEventID : nil
            )

            _ = try await snapMapViewModel.postSnap(draft: draft, currentProfile: authManager.profile)
            onPosted()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
                .foregroundStyle(isSelected ? Color.liveOnInk : Color.liveInk)
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

            if let avatarURL = explorer.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: explorer.avatarSymbolName)
                            .font(.system(size: size * 0.43, weight: .black))
                            .foregroundStyle(Color.liveInk)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: explorer.avatarSymbolName)
                    .font(.system(size: size * 0.43, weight: .black))
                    .foregroundStyle(Color.liveInk)
            }
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
    let currentUserID: String?
    let onOpenDetail: (LiveEvent) -> Void
    let onRoute: (LiveEvent) -> Void
    let onToggleJoin: (LiveEvent) -> Void

    @State private var query = ""
    @State private var expandedEventID: String?

    private var filteredEvents: [LiveEvent] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeEvents = events.filter(\.isVisibleInPublicSurfaces)
        guard !trimmedQuery.isEmpty else { return activeEvents }

        return activeEvents.filter { event in
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
                            currentUserID: currentUserID,
                            isShowingDetails: expandedEventID == event.id,
                            onToggleDetails: {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                                    expandedEventID = expandedEventID == event.id ? nil : event.id
                                }
                            },
                            onOpenDetail: { onOpenDetail(event) },
                            onRoute: { onRoute(event) },
                            onToggleJoin: { onToggleJoin(event) },
                            onReport: {},
                            onEdit: {}
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
private struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
        }
    }
}


private enum SocialListType: String, Identifiable {
    case followers = "Followers"
    case following = "Following"
    var id: String { rawValue }
}

private struct SocialListView: View {
    let type: SocialListType
    let targetUserID: UUID?
    let onSelectProfile: (Explorer) -> Void
    let onDismiss: () -> Void

    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private let profileService = ProfileService()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(Color.liveInk)
                            .padding(.vertical, 32)
                    } else if let errorMessage {
                        EmptyStateBlock(
                            symbolName: "exclamationmark.triangle.fill",
                            title: "Could not load \(type.rawValue.lowercased())",
                            message: errorMessage
                        )
                    } else if profiles.isEmpty {
                        EmptyStateBlock(
                            symbolName: "person.2.fill",
                            title: "No \(type.rawValue.lowercased()) yet",
                            message: "Approved relationships will appear here."
                        )
                    } else {
                        ForEach(profiles) { profile in
                            Button {
                                onDismiss()
                                onSelectProfile(profile.explorer)
                            } label: {
                                HStack(spacing: 12) {
                                    ExplorerAvatar(explorer: profile.explorer, size: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.displayName)
                                            .font(.system(size: 15, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.liveInk)
                                        Text(profile.handle)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.liveMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(Color.liveMuted)
                                }
                                .padding(11)
                                .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.bold)
                }
            }
            .background(Color.liveCanvas)
        }
        .task {
            await loadProfiles()
        }
    }

    private func loadProfiles() async {
        guard let targetUserID else {
            isLoading = false
            return
        }

        do {
            if type == .followers {
                profiles = try await profileService.followers(of: targetUserID)
            } else {
                profiles = try await profileService.following(of: targetUserID)
            }
        } catch {
            errorMessage = "Check your connection and try again."
        }
        isLoading = false
    }
}

private struct ProfileSheetView: View {
    let explorer: Explorer
    let currentExplorer: Explorer
    let currentProfile: Profile?
    let snaps: [LiveSnap]
    let events: [LiveEvent]
    let joinedEventIDs: Set<String>
    let onMessage: () -> Void
    let onOpenProfile: (Explorer) -> Void
    let onRefreshProfile: () async -> Void
    let onLogout: (() -> Void)?
    let onDismiss: (() -> Void)?

    @State private var accountPrivacy: AccountPrivacy = .privateAccount
    @State private var selectedTab: ProfileContentTab = .map
    @State private var socialState = ProfileSocialState(followerCount: 0, followingCount: 0, isFollowing: false)
    @State private var isSocialLoading = false
    @State private var showingSocialList: SocialListType?
    @State private var isEditingProfile = false
    @State private var editUsername = ""
    @State private var editDisplayName = ""
    @State private var editBio = ""
    @State private var settingsMessage: String?
    private let profileService = ProfileService()

    private var isSelf: Bool {
        explorer.id == currentExplorer.id
    }

    private var targetUserID: UUID? {
        UUID(uuidString: explorer.id)
    }

    private var createdEvents: [LiveEvent] {
        events.filter { $0.host.id == explorer.id || $0.hostID == explorer.id }
    }

    private var joinedEvents: [LiveEvent] {
        guard isSelf else { return [] }
        return events.filter { joinedEventIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    HStack(alignment: .top, spacing: 16) {
                        if isSelf {
                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    isEditingProfile.toggle()
                                }
                            }) {
                                ExplorerAvatar(explorer: explorer, size: 84)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ExplorerAvatar(explorer: explorer, size: 84)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(explorer.displayName)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)
                                    .lineLimit(1)

                                if isSelf {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            isEditingProfile.toggle()
                                        }
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.liveMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                        }

                        Text(explorer.handle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMuted)

                        HStack(alignment: .center, spacing: 16) {
                            ProfileStat(value: "\(snaps.count)", label: "Snaps")

                            Button(action: { showingSocialList = .followers }) {
                                ProfileStat(value: "\(socialState.followerCount)", label: "Followers")
                            }.buttonStyle(.plain)

                            Button(action: { showingSocialList = .following }) {
                                ProfileStat(value: "\(socialState.followingCount)", label: "Following")
                            }.buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if !explorer.bio.isEmpty {
                    Text(explorer.bio)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                        .padding(.horizontal, 16)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        EventStatBadge(count: createdEvents.count, label: "Created")
                        EventStatBadge(count: joinedEvents.count, label: "Joined")
                    }
                    .padding(.horizontal, 16)
                }

                if !isSelf {
                    HStack(spacing: 9) {
                        Button {
                            Task { await toggleFollow() }
                        } label: {
                            Label(socialState.isFollowing ? "Following" : "Follow", systemImage: socialState.isFollowing ? "checkmark.circle.fill" : "plus.circle.fill")
                                .liveActionButton(fill: socialState.isFollowing ? Color.liveMint.opacity(0.35) : Color.liveInk, foreground: socialState.isFollowing ? Color.liveInk : Color.liveOnInk)
                        }
                        .disabled(isSocialLoading || targetUserID == nil)
                        .buttonStyle(.plain)

                        Button(action: onMessage) {
                            Label("Message", systemImage: "bubble.left.fill")
                                .liveActionButton(fill: Color.liveSurfaceElevated, foreground: Color.liveInk)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                if isEditingProfile {
                    EditProfileCard(
                        username: $editUsername,
                        displayName: $editDisplayName,
                        bio: $editBio,
                        isPrivate: accountPrivacy == .privateAccount,
                        onSave: { newImage in
                            await saveProfile(newImage: newImage)
                        }
                    )
                    .padding(.horizontal, 16)
                }

                Picker("Profile section", selection: $selectedTab) {
                    ForEach(ProfileContentTab.allCases.filter { isSelf ? true : $0 != .settings }) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                profileTabContent
                    .padding(.horizontal, 16)

                if selectedTab == .settings, isSelf {
                    AccountSettingsCard(selection: $accountPrivacy)

                    VStack(alignment: .leading, spacing: 10) {
                        SettingsRow(symbolName: "person.text.rectangle.fill", title: "Account", value: explorer.handle)
                        SettingsRow(symbolName: "app.badge.fill", title: "App version", value: "MVP TestFlight")
                        SettingsRow(symbolName: "ladybug.fill", title: "Report a bug", value: "Coming soon")

                        if let settingsMessage {
                            Text(settingsMessage)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.liveMuted)
                        }
                    }
                    .padding(13)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let onLogout {
                        Button(action: onLogout) {
                            Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                .liveActionButton(fill: Color.liveInk, foreground: Color.liveOnInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color.liveCanvas)
            .sheet(item: $showingSocialList) { type in
                SocialListView(type: type, targetUserID: targetUserID, onSelectProfile: onOpenProfile) {
                    showingSocialList = nil
                }
                .presentationDetents([.medium, .large])
            }
            .task {
                seedEditFields()
                await loadSocialState()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.liveInk)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var profileTabContent: some View {
        switch selectedTab {
        case .map:
            if !snaps.isEmpty {
                Map(position: .constant(.region(region(for: snaps)))) {
                    ForEach(snaps) { snap in
                        Annotation(snap.title, coordinate: snap.coordinate, anchor: .bottom) {
                            SnapPhotoPin(snap: snap)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(true)
            } else {
                EmptyStateBlock(symbolName: "map.fill", title: "No map memories yet", message: isSelf ? "Post your first live snap to start building your personal map." : "This person has no visible snaps yet.")
            }
        case .snaps:
            if snaps.isEmpty {
                EmptyStateBlock(symbolName: "camera.fill", title: "No snaps yet", message: "Live snaps will collect here after posting.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(snaps) { snap in
                        HStack(spacing: 11) {
                            SnapImageFrame(snap: snap, height: 78, iconSize: 42, iconFontSize: 22)
                                .frame(width: 76, height: 78)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snap.title)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)
                                Text("\(snap.locationName) - \(snap.timeLabel)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.liveMuted)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        case .events:
            let displayEvents = isSelf ? joinedEvents : createdEvents
            if displayEvents.isEmpty {
                EmptyStateBlock(symbolName: "calendar", title: "No events yet", message: isSelf ? "Events you join or create will show here." : "Created events will show here.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displayEvents) { event in
                        HStack(spacing: 11) {
                            EventThumbnail(event: event)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liveInk)
                                    .strikethrough(event.isExpiredForPublicSurfaces, color: Color.liveAlertRed)
                                Text("\(event.locationName) - \(event.timeLabel)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.liveMuted)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .center) {
                            if event.isExpiredForPublicSurfaces {
                                Rectangle()
                                    .fill(Color.liveAlertRed.opacity(0.78))
                                    .frame(height: 2)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        case .settings:
            EmptyView()
        }
    }

    private func seedEditFields() {
        guard editUsername.isEmpty, editDisplayName.isEmpty else { return }
        editUsername = explorer.handle.replacingOccurrences(of: "@", with: "")
        editDisplayName = explorer.displayName
        editBio = explorer.bio
        accountPrivacy = currentProfile?.isPrivate == true ? .privateAccount : .publicAccount
    }

    private func loadSocialState() async {
        guard let targetUserID else {
            socialState = ProfileSocialState(
                followerCount: explorer.followers,
                followingCount: explorer.following,
                isFollowing: false
            )
            return
        }

        do {
            socialState = try await profileService.socialState(currentUserID: currentProfile?.id, targetUserID: targetUserID)
        } catch {
            socialState = ProfileSocialState(
                followerCount: explorer.followers,
                followingCount: explorer.following,
                isFollowing: false
            )
        }
    }

    private func toggleFollow() async {
        guard let currentUserID = currentProfile?.id, let targetUserID, currentUserID != targetUserID else { return }
        isSocialLoading = true
        defer { isSocialLoading = false }

        do {
            if socialState.isFollowing {
                try await profileService.unfollow(currentUserID: currentUserID, targetUserID: targetUserID)
            } else {
                try await profileService.follow(currentUserID: currentUserID, targetUserID: targetUserID)
            }
            await loadSocialState()
        } catch {
            settingsMessage = "Follow action did not sync. Check Supabase RLS."
        }
    }

    private func saveProfile(newImage: UIImage?) async {
        guard let userID = currentProfile?.id else { return }
        do {
            var avatarURL = currentProfile?.avatarURL

            if let image = newImage, let jpegData = image.liveCompressedJPEGData(maxPixelDimension: 900, compressionQuality: 0.68) {
                let path = "\(userID.uuidString.lowercased())/avatar-\(UUID().uuidString.lowercased()).jpg"
                try await supabase.storage
                    .from("avatars")
                    .upload(
                        path,
                        data: jpegData,
                        options: FileOptions(
                            cacheControl: "3600",
                            contentType: "image/jpeg",
                            upsert: true
                        )
                    )
                avatarURL = try await supabase.storage.from("avatars").getPublicURL(path: path).absoluteString
            }

            _ = try await profileService.updateProfile(
                userID: userID,
                username: editUsername,
                displayName: editDisplayName,
                bio: editBio,
                isPrivate: accountPrivacy == .privateAccount,
                avatarURL: avatarURL
            )
            settingsMessage = "Profile saved."
            await onRefreshProfile()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isEditingProfile = false
            }
        } catch {
            settingsMessage = error.localizedDescription
        }
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

private enum ProfileContentTab: String, CaseIterable, Identifiable {
    case map = "Map"
    case snaps = "Snaps"
    case events = "Events"
    case settings = "Settings"

    var id: String { rawValue }
}

private struct EditProfileCard: View {
    @Binding var username: String
    @Binding var displayName: String
    @Binding var bio: String
    let isPrivate: Bool
    let onSave: (UIImage?) async -> Void

    @State private var isSaving = false
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var newProfileImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit profile")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            HStack {
                Spacer()
                PhotosPicker(selection: $selectedProfileImage, matching: .images) {
                    if let newProfileImage {
                        Image(uiImage: newProfileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle().fill(Color.liveMuted.opacity(0.2)).frame(width: 84, height: 84)
                            Image(systemName: "camera.fill")
                                .foregroundStyle(Color.liveInk)
                                .font(.system(size: 24, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: selectedProfileImage) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                            newProfileImage = uiImage
                        }
                    }
                }
                Spacer()
            }
            .padding(.bottom, 10)

            TextField("Username", text: $username)
                .liveFieldStyle()
                .textInputAutocapitalization(.never)

            TextField("Display name", text: $displayName)
                .liveFieldStyle()

            TextEditor(text: $bio)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.liveInk)
                .frame(minHeight: 88)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 10))

            Text(isPrivate ? "Private account placeholder enabled." : "Public account placeholder enabled.")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)

            Button {
                Task {
                    isSaving = true
                    await onSave(newProfileImage)
                    isSaving = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.liveOnInk)
                    }
                    Text(isSaving ? "Saving..." : "Save profile")
                }
                .liveActionButton(fill: Color.liveInk, foreground: Color.liveOnInk)
            }
            .disabled(isSaving)
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsRow: View {
    let symbolName: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            PixelMiniSymbol(symbolName: symbolName, color: Color.liveInk)
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
                .lineLimit(1)
        }
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
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.liveInk)
                }

                Text("\(streakCount) day streak")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)
            }

            Text("Keep it alive by opening L!V!N every day.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.liveMuted)

            StreakCalendarView(streakCount: streakCount)

            Spacer()
        }
        .padding(20)
        .background(Color.liveCanvas)
    }
}

private struct StreakCalendarView: View {
    let streakCount: Int
    @State private var currentMonth: Date = Date()
    @AppStorage("lastAppOpenDate") private var lastAppOpenDate: Double = 0

    private let calendar = Calendar.current
    private let daysInWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }

    private func getDays() -> [Date?] {
        var days: [Date?] = []
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return days }

        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        var date = firstDayOfMonth
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func isActive(date: Date) -> Bool {
        if lastAppOpenDate == 0 { return false }
        let lastDate = Date(timeIntervalSince1970: lastAppOpenDate)

        let startOfLast = calendar.startOfDay(for: lastDate)
        let startOfCurrent = calendar.startOfDay(for: date)

        if startOfCurrent > startOfLast { return false }

        let components = calendar.dateComponents([.day], from: startOfCurrent, to: startOfLast)
        if let diff = components.day, diff < streakCount {
            return true
        }

        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(monthYearString)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.liveInk)
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.liveInk)
                    }
                }
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInWeek.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.liveMuted)
                }

                let monthDays = getDays()
                ForEach(Array(monthDays.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        let active = isActive(date: date)
                        let isToday = calendar.isDateInToday(date)

                        ZStack {
                            Circle()
                                .fill(active ? Color.liveLemon : (isToday ? Color.liveSurface : Color.clear))

                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14, weight: active || isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(active || isToday ? Color.liveInk : Color.liveMuted)
                        }
                        .frame(height: 34)
                    } else {
                        Color.clear
                            .frame(height: 34)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
    }
}

private struct InboxView: View {
    let currentUserID: UUID?
    let onOpenDM: (Profile) -> Void

    @State private var threads: [InboxThread] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let dmService = DMService()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 11) {
                    if isLoading {
                        ProgressView()
                            .tint(Color.liveInk)
                            .padding(.vertical, 34)
                    } else if threads.isEmpty {
                        EmptyStateBlock(
                            symbolName: "person.2.fill",
                            title: "No conversations yet",
                            message: "Start a chat from a friend's profile."
                        )
                    } else {
                        ForEach(threads) { thread in
                            Button {
                                onOpenDM(thread.profile)
                            } label: {
                                HStack(spacing: 12) {
                                    ExplorerAvatar(explorer: thread.profile.explorer, size: 48)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(thread.profile.displayName)
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.liveInk)

                                        Text(thread.lastMessage)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.liveMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundStyle(Color.liveInk)
                                }
                                .padding(12)
                                .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveAlertRed)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(18)
            }
            .background(Color.liveCanvas)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadThreads()
        }
    }

    private func loadThreads() async {
        isLoading = true
        errorMessage = nil

        do {
            threads = try await dmService.fetchRecentConversations()
        } catch {
            errorMessage = "Conversations could not load yet. Check Supabase RLS and auth."
        }

        isLoading = false
    }
}

private struct DirectMessageView: View {
    let targetExplorer: Explorer
    let currentUserID: UUID?

    @StateObject private var viewModel = DirectMessageViewModel()
    @State private var messageText = ""

    private var targetProfile: Profile? {
        Profile.liveProfile(from: targetExplorer)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let targetProfile {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            HStack(spacing: 12) {
                                ExplorerAvatar(explorer: targetExplorer, size: 52)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(targetExplorer.displayName)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.liveInk)
                                    Text(targetExplorer.handle)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.liveMuted)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 12))

                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color.liveInk)
                                    .padding(.vertical, 32)
                            } else if viewModel.messages.isEmpty {
                                EmptyStateBlock(
                                    symbolName: "bubble.left.fill",
                                    title: "Start the DM",
                                    message: "Keep it simple: say where you saw their snap or what event you both joined."
                                )
                            } else {
                                ForEach(viewModel.messages) { message in
                                    ChatBubble(message: message)
                                }
                            }
                        }
                        .padding(16)
                    }

                    if let error = viewModel.errorMessage ?? viewModel.realtimeWarning {
                        Text(error)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveAlertRed)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 9) {
                        TextField("Message \(targetExplorer.handle)", text: $messageText)
                            .liveFieldStyle()

                        Button {
                            let body = messageText
                            messageText = ""
                            Task {
                                await viewModel.send(currentUserID: currentUserID, targetProfile: targetProfile, body: body)
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color.liveOnInk)
                                .frame(width: 42, height: 42)
                                .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .task {
                        await viewModel.prepare(currentUserID: currentUserID, targetProfile: targetProfile)
                    }
                    .onDisappear {
                        viewModel.stopRealtime()
                    }
                } else {
                    EmptyStateBlock(
                        symbolName: "bubble.left.and.bubble.right.fill",
                        title: "Real profile needed",
                        message: "DMs work with Supabase profiles. Local demo profiles are display-only."
                    )
                    .padding(18)
                    Spacer()
                }
            }
            .background(Color.liveCanvas)
            .navigationTitle("Direct Message")
            .navigationBarTitleDisplayMode(.inline)
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
    var isExpiredForPublicSurfaces: Bool {
        guard let endsAt else { return false }
        return Date() > endsAt.addingTimeInterval(3 * 24 * 60 * 60)
    }

    var isVisibleInPublicSurfaces: Bool {
        !isExpiredForPublicSurfaces
    }

    var dateTimeSummary: String {
        if let startsAt, let endsAt {
            return "\(startsAt.liveDetailTimeLabel) - \(endsAt.liveDetailTimeLabel)"
        }
        return timeLabel
    }

    var capacityText: String {
        if let capacity {
            "\(attendeeCount)/\(capacity)"
        } else {
            "\(attendeeCount)/∞"
        }
    }

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

private extension Date {
    var liveDetailTimeLabel: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInTomorrow(self) {
            formatter.dateFormat = "'Tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: self)
    }
}

extension UIImage {
    func liveCompressedJPEGData(maxPixelDimension: CGFloat, compressionQuality: CGFloat) -> Data? {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixelDimension else {
            return jpegData(compressionQuality: compressionQuality)
        }

        let scale = maxPixelDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }

    func liveWatermarked(_ text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
            let fontSize = max(22, min(size.width, size.height) * 0.045)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .black),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            let textSize = text.size(withAttributes: attributes)
            let padding = fontSize * 0.7
            let rect = CGRect(
                x: size.width - textSize.width - padding,
                y: size.height - textSize.height - padding,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: rect, withAttributes: attributes)
        }
    }
}

private extension Profile {
    static func liveProfile(from explorer: Explorer) -> Profile? {
        guard let id = UUID(uuidString: explorer.id) else { return nil }
        return Profile(
            id: id,
            username: explorer.handle.replacingOccurrences(of: "@", with: ""),
            displayName: explorer.displayName,
            bio: explorer.bio,
            avatarURL: nil,
            isPrivate: false,
            isVerified: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private extension View {
    func liveFieldStyle() -> some View {
        self
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.liveInk)
            .padding(13)
            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.liveStroke, lineWidth: 1)
            }
    }

    func liveActionButton(fill: Color, foreground: Color) -> some View {
        self
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension Color {
    static let liveInk = dynamicColor(
        light: UIColor(red: 0.05, green: 0.07, blue: 0.17, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 1)
    )
    static let liveOnInk = dynamicColor(
        light: UIColor.white,
        dark: UIColor(red: 0.035, green: 0.045, blue: 0.11, alpha: 1)
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

private struct EventStatBadge: View {
    let count: Int
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 14, weight: .black, design: .rounded))
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.liveInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
