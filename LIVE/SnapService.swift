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
        let snapResponse: PostgrestResponse<[Snap]> = try await supabase
            .from("snaps")
            .select()
            .eq("is_public", value: true)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()

        let profileResponse: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .execute()

        let profilesByID = Dictionary(uniqueKeysWithValues: profileResponse.value.map { ($0.id, $0) })

        var liveSnaps: [LiveSnap] = []
        for snap in snapResponse.value {
            let signedURL = try? await signedURL(for: snap.firstMediaPath)
            liveSnaps.append(snap.liveSnap(profile: profilesByID[snap.creatorID], imageURL: signedURL))
        }

        return liveSnaps
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
        guard let jpegData = draft.image.jpegData(compressionQuality: 0.78) else {
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
