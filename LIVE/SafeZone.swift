//
//  SafeZone.swift
//  LIVE
//

import Foundation
import CoreLocation

struct SafeZone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double // in meters

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func processCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard let data = UserDefaults.standard.data(forKey: "live_safe_zones"),
              let zones = try? JSONDecoder().decode([SafeZone].self, from: data) else {
            return coordinate
        }

        let locSnap = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        for zone in zones {
            let locZone = CLLocation(latitude: zone.latitude, longitude: zone.longitude)
            if locSnap.distance(from: locZone) <= zone.radius {
                let latShift = Double.random(in: 0.018...0.025) * (Bool.random() ? 1.0 : -1.0)
                let lonShift = Double.random(in: 0.018...0.025) * (Bool.random() ? 1.0 : -1.0)
                return CLLocationCoordinate2D(
                    latitude: coordinate.latitude + latShift,
                    longitude: coordinate.longitude + lonShift
                )
            }
        }
        return coordinate
    }
}
