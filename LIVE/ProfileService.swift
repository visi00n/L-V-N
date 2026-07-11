//
//  ProfileService.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import Foundation
import Supabase

struct ProfileSocialState: Equatable {
    var followerCount: Int
    var followingCount: Int
    var isFollowing: Bool
    var isFriend: Bool = false
}

final class ProfileService {
    func fetchReadableProfiles() async throws -> [Profile] {
        let response: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .order("created_at", ascending: false)
            .limit(100)
            .execute()

        return response.value
    }

    func updateProfile(userID: UUID, username: String, displayName: String, bio: String, isPrivate: Bool, avatarURL: String?) async throws -> Profile {
        let update = ProfileUpdate(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "").lowercased(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            isPrivate: isPrivate,
            avatarURL: avatarURL
        )

        let response: PostgrestResponse<[Profile]>
        do {
            response = try await supabase
                .from("profiles")
                .update(update)
                .eq("id", value: userID)
                .select()
                .execute()
        } catch {
            if Self.isDuplicateUsernameError(error) {
                throw ProfileServiceError.message("That username is already taken.")
            }
            throw error
        }

        guard let profile = response.value.first else {
            throw ProfileServiceError.message("Profile was not returned after saving.")
        }

        return profile
    }

    func socialState(currentUserID: UUID?, targetUserID: UUID) async throws -> ProfileSocialState {
        let followers: PostgrestResponse<[Follow]> = try await supabase
            .from("follows")
            .select()
            .eq("following_id", value: targetUserID)
            .eq("status", value: "approved")
            .execute()

        let following: PostgrestResponse<[Follow]> = try await supabase
            .from("follows")
            .select()
            .eq("follower_id", value: targetUserID)
            .eq("status", value: "approved")
            .execute()

        var isFollowing = false
        var isFriend = false
        if let currentUserID {
            isFollowing = followers.value.contains { $0.followerID == currentUserID && $0.status == "approved" }
            let targetFollowsCurrentUser = following.value.contains { $0.followingID == currentUserID && $0.status == "approved" }
            isFriend = isFollowing && targetFollowsCurrentUser
        }

        return ProfileSocialState(
            followerCount: followers.value.count,
            followingCount: following.value.count,
            isFollowing: isFollowing,
            isFriend: isFriend
        )
    }

    func followers(of userID: UUID) async throws -> [Profile] {
        try await socialProfiles(for: userID, showingFollowers: true)
    }

    func following(of userID: UUID) async throws -> [Profile] {
        try await socialProfiles(for: userID, showingFollowers: false)
    }

    func fetchFriends(of userID: UUID) async throws -> [Profile] {
        let followingProfiles = try await following(of: userID)
        let followerProfiles = try await followers(of: userID)
        let followerIDs = Set(followerProfiles.map { $0.id })
        return followingProfiles.filter { followerIDs.contains($0.id) }
    }

    func follow(currentUserID: UUID, targetUserID: UUID) async throws {
        let insert = FollowInsert(
            followerID: currentUserID,
            followingID: targetUserID,
            status: "approved"
        )

        try await supabase
            .from("follows")
            .upsert(insert, onConflict: "follower_id,following_id")
            .execute()
    }

    func unfollow(currentUserID: UUID, targetUserID: UUID) async throws {
        try await supabase
            .from("follows")
            .delete()
            .eq("follower_id", value: currentUserID)
            .eq("following_id", value: targetUserID)
            .execute()
    }

    private func socialProfiles(for userID: UUID, showingFollowers: Bool) async throws -> [Profile] {
        let response: PostgrestResponse<[Follow]> = try await supabase
            .from("follows")
            .select()
            .eq(showingFollowers ? "following_id" : "follower_id", value: userID)
            .eq("status", value: "approved")
            .execute()

        let profileIDs = Set(response.value.map { showingFollowers ? $0.followerID : $0.followingID })
        guard !profileIDs.isEmpty else { return [] }

        let profiles: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .in("id", values: Array(profileIDs))
            .execute()

        return profiles.value
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func isDuplicateUsernameError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("profiles_username_key")
            || (message.contains("duplicate key") && message.contains("username"))
    }
}

private enum ProfileServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}
