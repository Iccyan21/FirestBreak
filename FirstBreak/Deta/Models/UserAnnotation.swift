//
//  UserAnnotation.swift.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import Foundation
import MapKit

struct User: Identifiable {
    let id = UUID()
    var profile: UserProfile
    var coordinate: CLLocationCoordinate2D {
        profile.coordinate
    }
}


