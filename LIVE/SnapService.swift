//
//  SnapService.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import CoreLocation
import Foundation
import Supabase
import UIKit

struct SnapDraft {
    let image: UIImage
    let caption: String
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let attachedEventID: String?
}

final class SnapService {
    private let bucketID = "snap-media"

    func fetchPublicSnaps() async throws -> [LiveSnap] {
        let session = try await supabase.auth.session
        let userID = session.user.id

        let snapResponse: PostgrestResponse<[Snap]> = try await supabase
            .from("snaps")
            .select()
            .order("created_at", ascending: false)
            .limit(250)
            .execute()

        let profileResponse: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .execute()

        let profilesByID = Dictionary(uniqueKeysWithValues: profileResponse.value.map { ($0.id, $0) })
        let snapIDs = snapResponse.value.map(\.id)
        let snapIDSet = Set(snapIDs)
        let likes = (try? await fetchLikes(for: snapIDs)) ?? []
        let comments = (try? await fetchCommentCounts(for: snapIDs)) ?? [:]
        let likesBySnapID = Dictionary(grouping: likes, by: \.snapID)

        var liveSnaps: [LiveSnap] = []
        for snap in snapResponse.value where snapIDSet.contains(snap.id) {
            let signedURL = try? await signedURL(for: snap.firstMediaPath)
            var liveSnap = snap.liveSnap(profile: profilesByID[snap.creatorID], imageURL: signedURL)
            let snapLikes = likesBySnapID[snap.id, default: []]
            liveSnap.likesCount = snapLikes.count
            liveSnap.commentsCount = comments[snap.id, default: 0]
            liveSnap.hasLiked = snapLikes.contains { $0.userID == userID }
            liveSnaps.append(liveSnap)
        }

        return liveSnaps
    }

    private func fetchLikes(for snapIDs: [UUID]) async throws -> [SnapLike] {
        guard !snapIDs.isEmpty else { return [] }
        let response: PostgrestResponse<[SnapLike]> = try await supabase
            .from("snap_likes")
            .select()
            .in("snap_id", values: snapIDs.map(\.uuidString))
            .execute()
        return response.value
    }

    private func fetchCommentCounts(for snapIDs: [UUID]) async throws -> [UUID: Int] {
        guard !snapIDs.isEmpty else { return [:] }
        let response: PostgrestResponse<[SnapComment]> = try await supabase
            .from("snap_comments")
            .select()
            .in("snap_id", values: snapIDs.map(\.uuidString))
            .execute()
        return Dictionary(grouping: response.value, by: \.snapID)
            .mapValues(\.count)
    }

    func createSnap(draft: SnapDraft, currentProfile: Profile?) async throws -> LiveSnap {
        let session = try await supabase.auth.session
        let userID = session.user.id
        let cleanCaption = draft.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCaption.isEmpty else {
            throw SnapServiceError.message("Missing caption.")
        }
        guard !cleanLocation.isEmpty else {
            throw SnapServiceError.message("Missing location name.")
        }
        guard let jpegData = draft.image.liveCompressedJPEGData(maxPixelDimension: 1600, compressionQuality: 0.64) else {
            throw SnapServiceError.message("Could not compress this photo.")
        }

        let storagePath = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        try await supabase.storage
            .from(bucketID)
            .upload(
                storagePath,
                data: jpegData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        let insert = SnapInsert(
            creatorID: userID,
            attachedEventID: draft.attachedEventID.flatMap(UUID.init(uuidString:)),
            caption: cleanCaption,
            locationName: cleanLocation,
            latitude: draft.coordinate.latitude,
            longitude: draft.coordinate.longitude,
            firstMediaPath: storagePath,
            mediaCount: 1,
            isPublic: true
        )

        let snapResponse: PostgrestResponse<[Snap]> = try await supabase
            .from("snaps")
            .insert(insert, returning: .representation)
            .select()
            .execute()

        guard let snap = snapResponse.value.first else {
            throw SnapServiceError.message("Snap was uploaded, but Supabase did not return the snap row.")
        }

        let mediaInsert = SnapMediaInsert(
            snapID: snap.id,
            storagePath: storagePath,
            sortOrder: 0
        )

        try await supabase
            .from("snap_media")
            .insert(mediaInsert)
            .execute()

        return snap.liveSnap(profile: currentProfile, imageURL: try? await signedURL(for: storagePath))
    }

    func signedURL(for path: String) async throws -> URL {
        try await supabase.storage
            .from(bucketID)
            .createSignedURL(path: path, expiresIn: 60 * 60)
    }

    func toggleLike(snapID: String, isLiked: Bool) async throws {
        let session = try await supabase.auth.session
        let userID = session.user.id

        if isLiked {
            let insert = SnapLikeInsert(
                snapID: UUID(uuidString: snapID)!,
                userID: userID
            )
            try await supabase
                .from("snap_likes")
                .insert(insert)
                .execute()
        } else {
            try await supabase
                .from("snap_likes")
                .delete()
                .eq("snap_id", value: snapID)
                .eq("user_id", value: userID.uuidString)
                .execute()
        }
    }

    func fetchComments(snapID: String) async throws -> [(SnapComment, Profile?)] {
        let response: PostgrestResponse<[SnapComment]> = try await supabase
            .from("snap_comments")
            .select()
            .eq("snap_id", value: snapID)
            .order("created_at", ascending: true)
            .execute()

        let profileIDs = Array(Set(response.value.map(\.userID)))
        var profilesByID: [UUID: Profile] = [:]

        if !profileIDs.isEmpty {
            let profileResponse: PostgrestResponse<[Profile]> = try await supabase
                .from("profiles")
                .select()
                .in("id", values: profileIDs.map(\.uuidString))
                .execute()
            profilesByID = Dictionary(uniqueKeysWithValues: profileResponse.value.map { ($0.id, $0) })
        }

        return response.value.map { ($0, profilesByID[$0.userID]) }
    }

    func postComment(snapID: String, body: String) async throws {
        let session = try await supabase.auth.session
        let userID = session.user.id

        let insert = SnapCommentInsert(
            snapID: UUID(uuidString: snapID)!,
            userID: userID,
            body: body
        )

        try await supabase
            .from("snap_comments")
            .insert(insert)
            .execute()
    }
}

private enum SnapServiceError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}
