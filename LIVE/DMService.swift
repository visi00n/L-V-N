//
//  DMService.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import Combine
import Foundation
import Supabase

struct InboxThread: Identifiable, Equatable {
    let id: String
    let profile: Profile
    let lastMessage: String
}

final class DMService {
    func readableProfiles(excluding userID: UUID?) async throws -> [Profile] {
        try await ProfileService()
            .fetchReadableProfiles()
            .filter { $0.id != userID }
    }

    struct RecentConversationRow: Decodable {
        let conversationID: UUID
        let targetUserID: UUID
        let targetHandle: String
        let targetDisplayName: String
        let targetAvatarURL: String?
        let targetBio: String?
        let lastMessage: String
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case conversationID = "conversation_id"
            case targetUserID = "target_user_id"
            case targetHandle = "target_handle"
            case targetDisplayName = "target_display_name"
            case targetAvatarURL = "target_avatar_url"
            case targetBio = "target_bio"
            case lastMessage = "last_message"
            case updatedAt = "updated_at"
        }
    }

    func fetchRecentConversations() async throws -> [InboxThread] {
        let response: PostgrestResponse<[RecentConversationRow]> = try await supabase
            .rpc("get_recent_conversations")
            .execute()

        return response.value.map { row in
            let profile = Profile(
                id: row.targetUserID,
                username: row.targetHandle,
                displayName: row.targetDisplayName,
                bio: row.targetBio ?? "",
                avatarURL: row.targetAvatarURL,
                isPrivate: false,
                isVerified: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            return InboxThread(id: row.conversationID.uuidString, profile: profile, lastMessage: row.lastMessage)
        }
    }

    func findOrCreateConversation(currentUserID: UUID, targetUserID: UUID) async throws -> UUID {
        let conversationID: UUID = try await supabase
            .rpc(
                "create_direct_conversation",
                params: CreateDirectConversationParams(targetUserID: targetUserID)
            )
            .execute()
            .value

        return conversationID
    }

    func fetchMessages(conversationID: UUID, currentUserID: UUID?, targetProfile: Profile) async throws -> [LiveChatMessage] {
        let response: PostgrestResponse<[DirectMessage]> = try await supabase
            .from("direct_messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .order("created_at", ascending: true)
            .limit(200)
            .execute()

        let currentExplorer = currentUserID.map {
            Explorer(
                id: $0.uuidString,
                handle: "@you",
                displayName: "You",
                bio: "",
                avatarSymbolName: "person.fill",
                ventureScore: 0,
                streak: 0,
                followers: 0,
                following: 0
            )
        }

        return response.value.map { message in
            LiveChatMessage(
                id: message.id.uuidString,
                sender: message.senderID == currentUserID ? (currentExplorer ?? targetProfile.explorer) : targetProfile.explorer,
                body: message.body,
                timeLabel: message.createdAt.dmTimeLabel,
                isMine: message.senderID == currentUserID
            )
        }
    }

    func sendMessage(conversationID: UUID, senderID: UUID, body: String) async throws {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            throw DMServiceError.message("Message cannot be blank.")
        }

        let insert = DirectMessageInsert(
            conversationID: conversationID,
            senderID: senderID,
            body: cleanBody
        )

        try await supabase
            .from("direct_messages")
            .insert(insert)
            .execute()
    }
}

@MainActor
final class DirectMessageViewModel: ObservableObject {
    @Published private(set) var conversationID: UUID?
    @Published private(set) var messages: [LiveChatMessage] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var realtimeWarning: String?

    private let dmService = DMService()
    private var realtimeTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?

    func prepare(currentUserID: UUID?, targetProfile: Profile) async {
        guard let currentUserID else {
            errorMessage = "Log in before messaging."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let id = try await dmService.findOrCreateConversation(
                currentUserID: currentUserID,
                targetUserID: targetProfile.id
            )
            conversationID = id
            messages = try await dmService.fetchMessages(
                conversationID: id,
                currentUserID: currentUserID,
                targetProfile: targetProfile
            )
            startRealtime(conversationID: id, currentUserID: currentUserID, targetProfile: targetProfile)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func send(currentUserID: UUID?, targetProfile: Profile, body: String) async {
        guard let currentUserID else {
            errorMessage = "Log in before messaging."
            return
        }
        guard let conversationID else {
            errorMessage = "Conversation is still loading."
            return
        }

        do {
            try await dmService.sendMessage(conversationID: conversationID, senderID: currentUserID, body: body)
            messages = try await dmService.fetchMessages(
                conversationID: conversationID,
                currentUserID: currentUserID,
                targetProfile: targetProfile
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

    private func startRealtime(conversationID: UUID, currentUserID: UUID, targetProfile: Profile) {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            await self.listen(conversationID: conversationID, currentUserID: currentUserID, targetProfile: targetProfile)
        }
    }

    private func listen(conversationID: UUID, currentUserID: UUID, targetProfile: Profile) async {
        let channel = supabase.channel("dm:\(conversationID.uuidString)")
        realtimeChannel = channel
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "direct_messages",
            filter: .eq("conversation_id", value: conversationID.uuidString)
        )

        do {
            try await channel.subscribeWithError()
            realtimeWarning = nil
        } catch {
            realtimeWarning = "Realtime DMs unavailable. Reopen the chat to refresh."
            realtimeTask = nil
            return
        }

        for await action in insertions {
            guard !Task.isCancelled else { return }
            do {
                let message = try action.decodeRecord(as: DirectMessage.self, decoder: AnyJSON.decoder)
                guard message.conversationID == conversationID else { continue }
                messages = try await dmService.fetchMessages(
                    conversationID: conversationID,
                    currentUserID: currentUserID,
                    targetProfile: targetProfile
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        realtimeTask = nil
    }
}

private enum DMServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}

private struct CreateDirectConversationParams: Encodable {
    let targetUserID: UUID

    enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
    }
}

private extension Date {
    var dmTimeLabel: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: self)
    }
}
