//
//  EventChatService.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import Combine
import Foundation
import Supabase

struct LiveChatMessage: Identifiable, Equatable {
    let id: String
    let sender: Explorer
    let body: String
    let timeLabel: String
    let isMine: Bool
}

final class EventChatService {
    func fetchMessages(eventID: UUID, currentUserID: UUID?) async throws -> [LiveChatMessage] {
        let messageResponse: PostgrestResponse<[EventMessage]> = try await supabase
            .from("event_messages")
            .select()
            .eq("event_id", value: eventID)
            .order("created_at", ascending: true)
            .limit(200)
            .execute()

        let profileResponse: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .execute()

        let profilesByID = Dictionary(uniqueKeysWithValues: profileResponse.value.map { ($0.id, $0) })
        return messageResponse.value.map { message in
            LiveChatMessage(
                id: message.id.uuidString,
                sender: profilesByID[message.senderID]?.explorer ?? Explorer(
                    id: message.senderID.uuidString,
                    handle: "@livin",
                    displayName: "L!V!N",
                    bio: "",
                    avatarSymbolName: "person.fill",
                    ventureScore: 0,
                    streak: 0,
                    followers: 0,
                    following: 0
                ),
                body: message.body,
                timeLabel: message.createdAt.shortChatLabel,
                isMine: message.senderID == currentUserID
            )
        }
    }

    func sendMessage(eventID: UUID, senderID: UUID, body: String) async throws {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            throw EventChatServiceError.message("Message cannot be blank.")
        }

        let insert = EventMessageInsert(eventID: eventID, senderID: senderID, body: cleanBody)
        try await supabase
            .from("event_messages")
            .insert(insert)
            .execute()
    }
}

@MainActor
final class EventChatViewModel: ObservableObject {
    @Published private(set) var messages: [LiveChatMessage] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var realtimeWarning: String?

    private let chatService = EventChatService()
    private var realtimeTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?

    func load(eventID: UUID, currentUserID: UUID?) async {
        isLoading = true
        errorMessage = nil

        do {
            messages = try await chatService.fetchMessages(eventID: eventID, currentUserID: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func send(eventID: UUID, currentUserID: UUID?, body: String) async {
        guard let currentUserID else {
            errorMessage = "Log in before sending a message."
            return
        }

        do {
            try await chatService.sendMessage(eventID: eventID, senderID: currentUserID, body: body)
            await load(eventID: eventID, currentUserID: currentUserID)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func startRealtime(eventID: UUID, currentUserID: UUID?) {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            await self.listen(eventID: eventID, currentUserID: currentUserID)
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

    private func listen(eventID: UUID, currentUserID: UUID?) async {
        let channel = supabase.channel("event:\(eventID.uuidString):feed")
        realtimeChannel = channel
        let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "event_messages")

        do {
            try await channel.subscribeWithError()
            realtimeWarning = nil
        } catch {
            realtimeWarning = "Realtime chat unavailable. Pull out and back in to refresh."
            realtimeTask = nil
            return
        }

        for await action in insertions {
            guard !Task.isCancelled else { return }
            do {
                let message = try action.decodeRecord(as: EventMessage.self, decoder: AnyJSON.decoder)
                guard message.eventID == eventID else { continue }
                await load(eventID: eventID, currentUserID: currentUserID)
            } catch {
                await load(eventID: eventID, currentUserID: currentUserID)
            }
        }

        realtimeTask = nil
    }
}

private enum EventChatServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}

private extension Date {
    var shortChatLabel: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: self)
    }
}
