//
//  UserProfile.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import Foundation
import MapKit
import SwiftUI
import CoreLocation
import Combine

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    // ユーザーの興味
    var interests: [String]
    // 現在のステータスや状態
    var status: String
    // 位置
    var coordinate: CLLocationCoordinate2D
    
    enum CodingKeys: String, CodingKey {
        case id, name, interests, status
        case latitude, longitude
    }
    
    init(id: UUID = UUID(), name: String, interests: [String], status: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.interests = interests
        self.status = status
        self.coordinate = coordinate
    }
    // UserProfile を JSON 形式などに変換するための処理
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(interests, forKey: .interests)
        try container.encode(status, forKey: .status)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
    // デコード処理
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        interests = try container.decode([String].self, forKey: .interests)
        status = try container.decode(String.self, forKey: .status)
        
        // CLLocationCoordinate2Dのデコード
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
