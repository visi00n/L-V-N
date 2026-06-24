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

    func updateProfile(userID: UUID, username: String, displayName: String, bio: String, isPrivate: Bool) async throws -> Profile {
        let update = ProfileUpdate(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "").lowercased(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            isPrivate: isPrivate
        )

        let response: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userID)
            .select()
            .execute()

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
            .execute()

        let following: PostgrestResponse<[Follow]> = try await supabase
            .from("follows")
            .select()
            .eq("follower_id", value: targetUserID)
            .execute()

        var isFollowing = false
        if let currentUserID {
            isFollowing = followers.value.contains { $0.followerID == currentUserID && $0.status == "approved" }
        }

        return ProfileSocialState(
            followerCount: followers.value.count,
            followingCount: following.value.count,
            isFollowing: isFollowing
        )
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
