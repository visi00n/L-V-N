//
//  LiveModels.swift
//  LIVE
//
//  Created by Codex on 6/17/26.
//

import CoreLocation
import Foundation
import MapKit

enum LiveTab: String, CaseIterable, Identifiable {
    case events = "Events"
    case create = "Create"
    case map = "Map"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .events:
            "rectangle.stack.fill"
        case .create:
            "plus.circle.fill"
        case .map:
            "map.fill"
        }
    }
}

enum SnapPalette {
    case coral
    case mint
    case lavender
    case sky
    case lemon

    var symbolName: String {
        switch self {
        case .coral:
            "figure.volleyball"
        case .mint:
            "figure.hiking"
        case .lavender:
            "moon.stars.fill"
        case .sky:
            "water.waves"
        case .lemon:
            "sparkles"
        }
    }
}

enum EventPulse: Equatable {
    case fresh
    case soon
    case steady
}

struct Explorer: Identifiable, Equatable {
    let id: String
    let handle: String
    let displayName: String
    let bio: String
    let avatarSymbolName: String
    let ventureScore: Int
    let streak: Int
    let followers: Int
    let following: Int
}

struct LiveEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let host: Explorer
    let category: String
    let locationName: String
    let timeLabel: String
    let attendeeCount: Int
    let priceLabel: String
    let details: String
    let coordinate: CLLocationCoordinate2D
    let palette: SnapPalette
    let isSignedUp: Bool
    let pulse: EventPulse

    static func == (lhs: LiveEvent, rhs: LiveEvent) -> Bool {
        lhs.id == rhs.id
    }
}

struct LiveSnap: Identifiable, Equatable {
    let id: String
    let title: String
    let caption: String
    let creator: Explorer
    let locationName: String
    let timeLabel: String
    let coordinate: CLLocationCoordinate2D
    let imageCount: Int
    let palette: SnapPalette
    let attachedEventID: String?

    static func == (lhs: LiveSnap, rhs: LiveSnap) -> Bool {
        lhs.id == rhs.id
    }
}

enum LiveData {
    static let santaMonica = CLLocationCoordinate2D(latitude: 34.0101, longitude: -118.4969)
    static let griffithPark = CLLocationCoordinate2D(latitude: 34.1366, longitude: -118.2942)
    static let echoPark = CLLocationCoordinate2D(latitude: 34.0743, longitude: -118.2606)
    static let venice = CLLocationCoordinate2D(latitude: 33.9850, longitude: -118.4695)
    static let downtownLA = CLLocationCoordinate2D(latitude: 34.0448, longitude: -118.2474)
    static let mapFallback = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

    static let jett = Explorer(
        id: "jett",
        handle: "@jettsonaway",
        displayName: "Jett Sawyer",
        bio: "Volleyball, hikes, game nights, and anything that gets people outside.",
        avatarSymbolName: "figure.volleyball",
        ventureScore: 770,
        streak: 8,
        followers: 1240,
        following: 318
    )

    static let mira = Explorer(
        id: "mira",
        handle: "@miraruns",
        displayName: "Mira Chen",
        bio: "Morning runs, beach hangs, weekend hikes, and proof that the group actually showed up.",
        avatarSymbolName: "figure.run",
        ventureScore: 920,
        streak: 15,
        followers: 2104,
        following: 472
    )

    static let noah = Explorer(
        id: "noah",
        handle: "@noahoutside",
        displayName: "Noah Reyes",
        bio: "Finding the small events that make a normal week feel legendary.",
        avatarSymbolName: "sparkles",
        ventureScore: 640,
        streak: 5,
        followers: 868,
        following: 190
    )

    static let me = Explorer(
        id: "me",
        handle: "@yourlive",
        displayName: "Your Page",
        bio: "Places you actually went, people you met, memories you pinned.",
        avatarSymbolName: "person.fill",
        ventureScore: 430,
        streak: 4,
        followers: 286,
        following: 142
    )

    static let events: [LiveEvent] = [
        LiveEvent(id: "sunset-volleyball", title: "Sunset Volleyball", host: jett, category: "Open Venture", locationName: "Santa Monica Beach", timeLabel: "6:00 PM", attendeeCount: 34, priceLabel: "Free", details: "Show up before sunset, join a team, and snap the court when you get there.", coordinate: santaMonica, palette: .coral, isSignedUp: true, pulse: .soon),
        LiveEvent(id: "griffith-hike", title: "Griffith Night Hike", host: mira, category: "Outdoors", locationName: "Griffith Park", timeLabel: "7:15 PM", attendeeCount: 18, priceLabel: "Free", details: "A slow group hike with city views and a post-hike taco stop.", coordinate: griffithPark, palette: .mint, isSignedUp: true, pulse: .fresh),
        LiveEvent(id: "echo-picnic", title: "Echo Park Picnic", host: noah, category: "Social", locationName: "Echo Park Lake", timeLabel: "Saturday", attendeeCount: 22, priceLabel: "Free", details: "Blankets, cards, music, and a casual friend-of-friends picnic by the lake.", coordinate: echoPark, palette: .lemon, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "venice-cleanup", title: "Venice Cleanup Walk", host: mira, category: "Community", locationName: "Venice Boardwalk", timeLabel: "10:00 AM", attendeeCount: 41, priceLabel: "Free", details: "Walk the boardwalk, clean up together, then grab smoothies nearby.", coordinate: venice, palette: .sky, isSignedUp: false, pulse: .soon),
        LiveEvent(id: "dtla-rooftop", title: "DTLA Rooftop Sketch", host: noah, category: "Creative", locationName: "Arts District", timeLabel: "5:30 PM", attendeeCount: 16, priceLabel: "Free", details: "Bring a sketchbook or camera and trade favorite rooftop angles before sunset.", coordinate: CLLocationCoordinate2D(latitude: 34.0407, longitude: -118.2353), palette: .lavender, isSignedUp: false, pulse: .fresh),
        LiveEvent(id: "runyon-sunrise", title: "Runyon Sunrise Walk", host: mira, category: "Outdoors", locationName: "Runyon Canyon", timeLabel: "6:15 AM", attendeeCount: 28, priceLabel: "Free", details: "Easy pace up the trail, photo stop at the overlook, coffee after.", coordinate: CLLocationCoordinate2D(latitude: 34.1106, longitude: -118.3504), palette: .mint, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "koreatown-bites", title: "Ktown Food Crawl", host: jett, category: "Food", locationName: "Koreatown Plaza", timeLabel: "8:00 PM", attendeeCount: 12, priceLabel: "Free", details: "A small group crawl with three food stops and one dessert stop.", coordinate: CLLocationCoordinate2D(latitude: 34.0580, longitude: -118.3009), palette: .coral, isSignedUp: false, pulse: .soon),
        LiveEvent(id: "silverlake-records", title: "Record Store Loop", host: noah, category: "Music", locationName: "Silver Lake", timeLabel: "2:00 PM", attendeeCount: 9, priceLabel: "Free", details: "Browse records, swap favorite finds, then post a snap from the listening wall.", coordinate: CLLocationCoordinate2D(latitude: 34.0869, longitude: -118.2702), palette: .sky, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "beach-yoga", title: "Beach Yoga Reset", host: mira, category: "Wellness", locationName: "Will Rogers Beach", timeLabel: "9:00 AM", attendeeCount: 31, priceLabel: "Free", details: "Beginner-friendly stretch session near the water with a short walk after.", coordinate: CLLocationCoordinate2D(latitude: 34.0341, longitude: -118.5156), palette: .lemon, isSignedUp: false, pulse: .fresh),
        LiveEvent(id: "little-tokyo-photos", title: "Little Tokyo Photo Walk", host: noah, category: "Creative", locationName: "Japanese Village Plaza", timeLabel: "4:45 PM", attendeeCount: 19, priceLabel: "Free", details: "Find good storefront shots, neon details, and a group portrait before dinner.", coordinate: CLLocationCoordinate2D(latitude: 34.0488, longitude: -118.2399), palette: .lavender, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "pickup-basketball", title: "Pickup Basketball", host: jett, category: "Sports", locationName: "Pan Pacific Park", timeLabel: "6:30 PM", attendeeCount: 24, priceLabel: "Free", details: "Half-court games, rotating teams, and room for beginners to jump in.", coordinate: CLLocationCoordinate2D(latitude: 34.0740, longitude: -118.3618), palette: .coral, isSignedUp: false, pulse: .soon),
        LiveEvent(id: "museum-morning", title: "Museum Morning", host: mira, category: "Culture", locationName: "The Broad", timeLabel: "11:00 AM", attendeeCount: 14, priceLabel: "Free", details: "Walk the galleries together and pick one piece for a group discussion.", coordinate: CLLocationCoordinate2D(latitude: 34.0544, longitude: -118.2500), palette: .sky, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "farmers-market", title: "Farmers Market Hang", host: noah, category: "Food", locationName: "Hollywood Farmers Market", timeLabel: "10:30 AM", attendeeCount: 27, priceLabel: "Free", details: "Grab fruit, snacks, and quick portraits around the stands.", coordinate: CLLocationCoordinate2D(latitude: 34.0988, longitude: -118.3295), palette: .lemon, isSignedUp: false, pulse: .fresh),
        LiveEvent(id: "climbing-session", title: "Climbing Intro", host: jett, category: "Fitness", locationName: "The Stronghold", timeLabel: "7:00 PM", attendeeCount: 10, priceLabel: "Free", details: "First-timer friendly bouldering session with a small crew and rented shoes.", coordinate: CLLocationCoordinate2D(latitude: 34.0386, longitude: -118.2307), palette: .mint, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "board-game-cafe", title: "Board Game Cafe", host: noah, category: "Games", locationName: "Glendale", timeLabel: "7:30 PM", attendeeCount: 15, priceLabel: "Free", details: "Low-pressure table games, quick introductions, and rotating groups.", coordinate: CLLocationCoordinate2D(latitude: 34.1425, longitude: -118.2551), palette: .lavender, isSignedUp: false, pulse: .soon),
        LiveEvent(id: "malibu-lookout", title: "Malibu Lookout Stop", host: mira, category: "Outdoors", locationName: "Malibu Bluffs", timeLabel: "3:30 PM", attendeeCount: 13, priceLabel: "Free", details: "Short scenic meetup for ocean photos and a snack stop nearby.", coordinate: CLLocationCoordinate2D(latitude: 34.0331, longitude: -118.6846), palette: .sky, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "pasadena-thrift", title: "Pasadena Thrift Loop", host: noah, category: "Style", locationName: "Old Pasadena", timeLabel: "1:00 PM", attendeeCount: 11, priceLabel: "Free", details: "Two thrift stops, one coffee stop, and outfit snaps if people are down.", coordinate: CLLocationCoordinate2D(latitude: 34.1459, longitude: -118.1509), palette: .coral, isSignedUp: false, pulse: .fresh),
        LiveEvent(id: "bike-to-the-pier", title: "Bike to the Pier", host: jett, category: "Outdoors", locationName: "Marina del Rey", timeLabel: "5:00 PM", attendeeCount: 20, priceLabel: "Free", details: "Easy group ride toward the pier with breaks for water and photos.", coordinate: CLLocationCoordinate2D(latitude: 33.9803, longitude: -118.4517), palette: .mint, isSignedUp: false, pulse: .steady),
        LiveEvent(id: "open-mic", title: "Open Mic Night", host: mira, category: "Music", locationName: "Highland Park", timeLabel: "8:30 PM", attendeeCount: 18, priceLabel: "Free", details: "Come perform or just watch. The first few rows are saved for L!V!N signups.", coordinate: CLLocationCoordinate2D(latitude: 34.1156, longitude: -118.1917), palette: .lavender, isSignedUp: false, pulse: .soon),
        LiveEvent(id: "bookstore-meet", title: "Bookstore Meetup", host: noah, category: "Social", locationName: "Culver City", timeLabel: "4:00 PM", attendeeCount: 17, priceLabel: "Free", details: "Pick a book, share why it caught your eye, then walk to a nearby cafe.", coordinate: CLLocationCoordinate2D(latitude: 34.0211, longitude: -118.3965), palette: .lemon, isSignedUp: false, pulse: .steady)
    ]

    static let snaps: [LiveSnap] = [
        LiveSnap(
            id: "beach-serve",
            title: "Beach serve warmup",
            caption: "First game started with the sky going pink.",
            creator: jett,
            locationName: "Santa Monica Beach",
            timeLabel: "12m ago",
            coordinate: santaMonica,
            imageCount: 4,
            palette: .coral,
            attachedEventID: "sunset-volleyball"
        ),
        LiveSnap(
            id: "trail-view",
            title: "City lights from the trail",
            caption: "Half the group wanted to keep climbing after this view.",
            creator: mira,
            locationName: "Griffith Park",
            timeLabel: "32m ago",
            coordinate: griffithPark,
            imageCount: 3,
            palette: .mint,
            attachedEventID: "griffith-hike"
        ),
        LiveSnap(
            id: "lake-blanket",
            title: "Picnic blanket claimed",
            caption: "Found the spot before everyone pulled up.",
            creator: noah,
            locationName: "Echo Park Lake",
            timeLabel: "1h ago",
            coordinate: echoPark,
            imageCount: 1,
            palette: .lemon,
            attachedEventID: nil
        ),
        LiveSnap(
            id: "venice-walk",
            title: "Boardwalk walk",
            caption: "Met two new people before coffee.",
            creator: mira,
            locationName: "Venice Boardwalk",
            timeLabel: "Yesterday",
            coordinate: venice,
            imageCount: 5,
            palette: .sky,
            attachedEventID: nil
        )
    ]

    static var signedUpEvents: [LiveEvent] {
        events.filter(\.isSignedUp)
    }
}
