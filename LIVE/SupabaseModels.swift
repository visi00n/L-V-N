//
//  SupabaseModels.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import CoreLocation
import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var username: String
    var displayName: String
    var bio: String?
    var avatarURL: String?
    var isPrivate: Bool
    var isVerified: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case isPrivate = "is_private"
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProfileInsert: Encodable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case isPrivate = "is_private"
    }
}

struct Snap: Codable, Identifiable, Equatable {
    let id: UUID
    let creatorID: UUID
    let attachedEventID: UUID?
    let caption: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let firstMediaPath: String
    let mediaCount: Int
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case attachedEventID = "attached_event_id"
        case caption
        case locationName = "location_name"
        case latitude
        case longitude
        case firstMediaPath = "first_media_path"
        case mediaCount = "media_count"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SnapInsert: Encodable {
    let creatorID: UUID
    let attachedEventID: UUID?
    let caption: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let firstMediaPath: String
    let mediaCount: Int
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case creatorID = "creator_id"
        case attachedEventID = "attached_event_id"
        case caption
        case locationName = "location_name"
        case latitude
        case longitude
        case firstMediaPath = "first_media_path"
        case mediaCount = "media_count"
        case isPublic = "is_public"
    }
}

struct SnapMedia: Codable, Identifiable, Equatable {
    let id: UUID
    let snapID: UUID
    let storagePath: String
    let sortOrder: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case snapID = "snap_id"
        case storagePath = "storage_path"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct SnapMediaInsert: Encodable {
    let snapID: UUID
    let storagePath: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case snapID = "snap_id"
        case storagePath = "storage_path"
        case sortOrder = "sort_order"
    }
}

struct Event: Codable, Identifiable, Equatable {
    let id: UUID
    let hostID: UUID
    let title: String
    let details: String
    let category: String
    let startsAt: Date
    let endsAt: Date?
    let locationName: String
    let latitude: Double
    let longitude: Double
    let isPaid: Bool
    let priceCents: Int?
    let capacity: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case hostID = "host_id"
        case title
        case details
        case category
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case locationName = "location_name"
        case latitude
        case longitude
        case isPaid = "is_paid"
        case priceCents = "price_cents"
        case capacity
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EventMember: Codable, Equatable {
    let eventID: UUID
    let userID: UUID
    let role: String
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

struct EventMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let eventID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
    }
}

extension Profile {
    var handle: String {
        username.hasPrefix("@") ? username : "@\(username)"
    }

    var explorer: Explorer {
        Explorer(
            id: id.uuidString,
            handle: handle,
            displayName: displayName,
            bio: bio ?? "",
            avatarSymbolName: "person.fill",
            ventureScore: 0,
            streak: 0,
            followers: 0,
            following: 0
        )
    }
}

extension Snap {
    func liveSnap(profile: Profile?, imageURL: URL?) -> LiveSnap {
        let creator = profile?.explorer ?? Explorer(
            id: creatorID.uuidString,
            handle: "@livin",
            displayName: "L!V!N Explorer",
            bio: "",
            avatarSymbolName: "person.fill",
            ventureScore: 0,
            streak: 0,
            followers: 0,
            following: 0
        )

        return LiveSnap(
            id: id.uuidString,
            title: caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Live snap" : caption,
            caption: caption,
            creator: creator,
            locationName: locationName,
            timeLabel: createdAt.relativeLiveLabel,
            coordinate: coordinate,
            imageCount: mediaCount,
            palette: Self.palette(for: id),
            attachedEventID: attachedEventID?.uuidString,
            firstMediaPath: firstMediaPath,
            imageURL: imageURL
        )
    }

    private static func palette(for id: UUID) -> SnapPalette {
        let palettes: [SnapPalette] = [.coral, .mint, .lavender, .sky, .lemon]
        let value = id.uuidString.utf8.reduce(0) { Int($0) + Int($1) }
        return palettes[value % palettes.count]
    }
}

private extension Date {
    var relativeLiveLabel: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 {
            return "now"
        }
        if interval < 3_600 {
            return "\(Int(interval / 60))m ago"
        }
        if interval < 86_400 {
            return "\(Int(interval / 3_600))h ago"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
