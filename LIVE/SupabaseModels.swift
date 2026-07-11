//
//  SupabaseModels.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import CoreLocation
import Foundation
import Supabase
import Storage

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

struct ProfileUpdate: Encodable {
    let username: String
    let displayName: String
    let bio: String
    let isPrivate: Bool
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case bio
        case isPrivate = "is_private"
        case avatarURL = "avatar_url"
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
        case creatorID = "user_id"
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
        case creatorID = "user_id"
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

struct SnapLike: Codable, Identifiable, Equatable {
    let id: UUID
    let snapID: UUID
    let userID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case snapID = "snap_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

struct SnapLikeInsert: Encodable {
    let snapID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case snapID = "snap_id"
        case userID = "user_id"
    }
}

struct SnapComment: Codable, Identifiable, Equatable {
    let id: UUID
    let snapID: UUID
    let userID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case snapID = "snap_id"
        case userID = "user_id"
        case body
        case createdAt = "created_at"
    }
}

struct SnapCommentInsert: Encodable {
    let snapID: UUID
    let userID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case snapID = "snap_id"
        case userID = "user_id"
        case body
    }
}

struct SnapWithStats: Codable {
    let snap: Snap
    let likesCount: Int
    let commentsCount: Int
    let hasLiked: Bool

    enum CodingKeys: String, CodingKey {
        case snap
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case hasLiked = "has_liked"
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
    let coverImagePath: String?
    let isPublic: Bool?
    let inviteToken: String?

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
        case coverImagePath = "cover_image_path"
        case isPublic = "is_public"
        case inviteToken = "invite_token"
    }
}

struct EventInsert: Encodable {
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
    let coverImagePath: String?
    let isPublic: Bool
    let inviteToken: String?

    enum CodingKeys: String, CodingKey {
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
        case coverImagePath = "cover_image_path"
        case isPublic = "is_public"
        case inviteToken = "invite_token"
    }
}

struct EventUpdate: Encodable {
    let title: String
    let details: String
    let category: String
    let startsAt: Date
    let endsAt: Date?
    let locationName: String
    let latitude: Double
    let longitude: Double
    let capacity: Int?
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case details
        case category
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case locationName = "location_name"
        case latitude
        case longitude
        case capacity
        case isPublic = "is_public"
    }
}

struct EventMember: Codable, Equatable {
    let eventID: UUID
    let userID: UUID
    let role: String
    let joinedAt: Date?

    var id: String {
        "\(eventID.uuidString)-\(userID.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

struct EventMemberInsert: Encodable {
    let eventID: UUID
    let userID: UUID
    let role: String

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case userID = "user_id"
        case role
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

struct EventMessageInsert: Encodable {
    let eventID: UUID
    let senderID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case senderID = "sender_id"
        case body
    }
}

struct Follow: Codable, Equatable {
    let followerID: UUID
    let followingID: UUID
    let status: String
    let createdAt: Date

    var id: String {
        "\(followerID.uuidString)-\(followingID.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case followerID = "follower_id"
        case followingID = "following_id"
        case status
        case createdAt = "created_at"
    }
}

struct FollowInsert: Encodable {
    let followerID: UUID
    let followingID: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case followerID = "follower_id"
        case followingID = "following_id"
        case status
    }
}

struct DirectConversation: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
    }
}

struct DirectConversationInsert: Encodable {}

struct DirectConversationMember: Codable, Equatable {
    let conversationID: UUID
    let userID: UUID
    let createdAt: Date

    var id: String {
        "\(conversationID.uuidString)-\(userID.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

struct DirectConversationMemberInsert: Encodable {
    let conversationID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case userID = "user_id"
    }
}

struct DirectMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
    }
}

struct DirectMessageInsert: Encodable {
    let conversationID: UUID
    let senderID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
    }
}

struct Report: Codable, Identifiable, Equatable {
    let id: UUID
    let reporterID: UUID
    let targetType: String
    let targetID: UUID
    let reason: String
    let details: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reporterID = "reporter_id"
        case targetType = "target_type"
        case targetID = "target_id"
        case reason
        case details
        case createdAt = "created_at"
    }
}

extension Profile {
    var handle: String {
        username.hasPrefix("@") ? username : "@\(username)"
    }

    var explorer: Explorer {
        let ig = UserDefaults.standard.string(forKey: "live_ig_\(id.uuidString)")
        let tt = UserDefaults.standard.string(forKey: "live_tt_\(id.uuidString)")
        return Explorer(
            id: id.uuidString,
            handle: handle,
            displayName: displayName,
            bio: bio ?? "",
            avatarSymbolName: "person.fill",
            avatarURL: avatarURL.flatMap(URL.init(string:)),
            ventureScore: 0,
            streak: 0,
            followers: 0,
            following: 0,
            instagramHandle: ig,
            tiktokHandle: tt
        )
    }
}

extension Event {
    func liveEvent(
        host: Profile?,
        attendeeCount: Int,
        isSignedUp: Bool
    ) -> LiveEvent {
        let eventCategory = LiveEventCategory(label: self.category)
        let hostExplorer = host?.explorer ?? Explorer(
            id: hostID.uuidString,
            handle: "@livinhost",
            displayName: "L!V!N Host",
            bio: "",
            avatarSymbolName: "person.fill",
            ventureScore: 0,
            streak: 0,
            followers: 0,
            following: 0
        )

        let imageURL: URL?
        if let path = coverImagePath, !path.isEmpty {
            imageURL = try? supabase.storage.from("event-covers").getPublicURL(path: path)
        } else {
            imageURL = nil
        }

        return LiveEvent(
            id: id.uuidString,
            title: title,
            host: hostExplorer,
            category: eventCategory.rawValue,
            locationName: locationName,
            timeLabel: startsAt.eventTimeLabel,
            attendeeCount: attendeeCount,
            priceLabel: isPaid ? priceLabel : "Free",
            details: details,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            palette: eventCategory.palette,
            isSignedUp: isSignedUp,
            pulse: pulse,
            hostID: hostID.uuidString,
            startsAt: startsAt,
            endsAt: endsAt,
            capacity: capacity,
            coverImageURL: imageURL,
            isPublic: isPublic ?? true,
            inviteToken: inviteToken
        )
    }

    private var priceLabel: String {
        guard let priceCents, priceCents > 0 else { return "Free" }
        return "$\(priceCents / 100)"
    }

    private var pulse: EventPulse {
        let now = Date()
        if startsAt.timeIntervalSince(now) <= 3 * 60 * 60, startsAt > now {
            return .soon
        }
        if createdAt.timeIntervalSince(now) > -24 * 60 * 60 {
            return .fresh
        }
        return .steady
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

extension SnapWithStats {
    func liveSnap(profile: Profile?, imageURL: URL?) -> LiveSnap {
        var result = snap.liveSnap(profile: profile, imageURL: imageURL)
        result.likesCount = likesCount
        result.commentsCount = commentsCount
        result.hasLiked = hasLiked
        return result
    }
}

private extension Date {
    var eventTimeLabel: String {
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
