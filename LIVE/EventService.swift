//
//  EventService.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import Combine
import CoreLocation
import Foundation
import UIKit
import Supabase
import SwiftUI

struct EventDraft {
    let title: String
    let category: String
    let details: String
    let startsAt: Date
    let endsAt: Date?
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let capacity: Int?
    let image: UIImage?
    let isPublic: Bool
}

final class EventService {
    func fetchEvents(currentUserID: UUID?) async throws -> ([LiveEvent], Set<String>) {
        let eventResponse: PostgrestResponse<[Event]> = try await supabase
            .from("events")
            .select()
            .order("created_at", ascending: false)
            .limit(100)
            .execute()

        let memberResponse: PostgrestResponse<[EventMember]> = try await supabase
            .from("event_members")
            .select()
            .execute()

        let profileResponse: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .execute()

        let profilesByID = Dictionary(uniqueKeysWithValues: profileResponse.value.map { ($0.id, $0) })
        let counts = Dictionary(grouping: memberResponse.value, by: \.eventID)
            .mapValues(\.count)
        let joinedIDs: Set<String> = Set(memberResponse.value.compactMap { member in
            guard member.userID == currentUserID else { return nil }
            return member.eventID.uuidString
        })

        let liveEvents = eventResponse.value.map { event in
            event.liveEvent(
                host: profilesByID[event.hostID],
                attendeeCount: counts[event.id, default: 0],
                isSignedUp: joinedIDs.contains(event.id.uuidString)
            )
        }

        return (liveEvents, joinedIDs)
    }

    func createEvent(draft: EventDraft, hostProfile: Profile) async throws -> LiveEvent {
        var storagePath: String? = nil

        if let image = draft.image, let jpegData = image.liveCompressedJPEGData(maxPixelDimension: 1800, compressionQuality: 0.7) {
            let path = "\(hostProfile.id.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await supabase.storage
                .from("event-covers")
                .upload(
                    path,
                    data: jpegData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )
            storagePath = path
        }

        let insert = EventInsert(
            hostID: hostProfile.id,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: draft.details.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category.trimmingCharacters(in: .whitespacesAndNewlines),
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            locationName: draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: draft.coordinate.latitude,
            longitude: draft.coordinate.longitude,
            isPaid: false,
            priceCents: nil,
            capacity: draft.capacity,
            coverImagePath: storagePath,
            isPublic: draft.isPublic,
            inviteToken: draft.isPublic ? nil : UUID().uuidString.lowercased()
        )

        guard !insert.title.isEmpty else {
            throw EventServiceError.message("Event title is required.")
        }
        guard !insert.locationName.isEmpty else {
            throw EventServiceError.message("Location name is required.")
        }

        let eventResponse: PostgrestResponse<[Event]> = try await supabase
            .from("events")
            .insert(insert, returning: .representation)
            .select()
            .execute()

        guard let event = eventResponse.value.first else {
            throw EventServiceError.message("Event was not returned by Supabase.")
        }

        let member = EventMemberInsert(
            eventID: event.id,
            userID: hostProfile.id,
            role: "owner"
        )

        try await supabase
            .from("event_members")
            .upsert(member, onConflict: "event_id,user_id")
            .execute()

        return event.liveEvent(host: hostProfile, attendeeCount: 1, isSignedUp: true)
    }

    func join(eventID: UUID, userID: UUID) async throws {
        let member = EventMemberInsert(eventID: eventID, userID: userID, role: "member")
        try await supabase
            .from("event_members")
            .upsert(member, onConflict: "event_id,user_id")
            .execute()
    }

    func leave(eventID: UUID, userID: UUID) async throws {
        try await supabase
            .from("event_members")
            .delete()
            .eq("event_id", value: eventID)
            .eq("user_id", value: userID)
            .execute()
    }
}

@MainActor
final class EventViewModel: ObservableObject {
    @Published private(set) var events: [LiveEvent] = LiveData.events
    @Published private(set) var joinedEventIDs: Set<String> = Set(LiveData.signedUpEvents.map(\.id))
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var realtimeWarning: String?

    private let eventService = EventService()
    private var realtimeTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?

    var statusMessage: String? {
        errorMessage ?? realtimeWarning
    }

    var joinedEvents: [LiveEvent] {
        events.filter { joinedEventIDs.contains($0.id) }
    }

    func loadEvents(currentUserID: UUID?) async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded = try await eventService.fetchEvents(currentUserID: currentUserID)
            let localOnly = LiveData.events.filter { local in
                !loaded.0.contains { $0.id == local.id }
            }
            let localEvents = (loaded.0 + localOnly).prefix(100).map { $0 }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                events = localEvents
            }
            joinedEventIDs.formUnion(loaded.1)
        } catch {
            errorMessage = "Events are showing from the local preview until Supabase is ready."
        }

        isLoading = false
    }

    func createEvent(draft: EventDraft, hostProfile: Profile) async throws -> LiveEvent {
        let event = try await eventService.createEvent(draft: draft, hostProfile: hostProfile)
        upsert(event)
        joinedEventIDs.insert(event.id)
        return event
    }

    func toggleJoin(_ event: LiveEvent, currentUserID: UUID?) async {
        if joinedEventIDs.contains(event.id) {
            joinedEventIDs.remove(event.id)
        } else {
            joinedEventIDs.insert(event.id)
        }

        guard let eventUUID = UUID(uuidString: event.id), let currentUserID else {
            return
        }

        do {
            if joinedEventIDs.contains(event.id) {
                try await eventService.join(eventID: eventUUID, userID: currentUserID)
            } else {
                try await eventService.leave(eventID: eventUUID, userID: currentUserID)
            }
            await loadEvents(currentUserID: currentUserID)
        } catch {
            realtimeWarning = "Event membership did not sync. Try again in a moment."
        }
    }

    func startRealtime(currentUserID: UUID?) {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForEvents(currentUserID: currentUserID)
        }
    }

    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let realtimeChannel {
            Task {
                await supabase.removeChannel(realtimeChannel)
            }
        }
        realtimeChannel = nil
    }

    private func upsert(_ event: LiveEvent) {
        events.removeAll { $0.id == event.id }
        events.insert(event, at: 0)
    }

    private func listenForEvents(currentUserID: UUID?) async {
        let channel = supabase.channel("events:feed")
        realtimeChannel = channel
        let eventInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "events")
        let memberInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "event_members")
        let memberDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "event_members")

        do {
            try await channel.subscribeWithError()
            realtimeWarning = nil
        } catch {
            realtimeWarning = "Realtime events unavailable. The list still refreshes on launch."
            realtimeTask = nil
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in eventInserts {
                    guard let self, !Task.isCancelled else { return }
                    await self.loadEvents(currentUserID: currentUserID)
                }
            }
            group.addTask { [weak self] in
                for await _ in memberInserts {
                    guard let self, !Task.isCancelled else { return }
                    await self.loadEvents(currentUserID: currentUserID)
                }
            }
            group.addTask { [weak self] in
                for await _ in memberDeletes {
                    guard let self, !Task.isCancelled else { return }
                    await self.loadEvents(currentUserID: currentUserID)
                }
            }
        }

        realtimeTask = nil
    }
}

private enum EventServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}
