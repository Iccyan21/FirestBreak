//
//  ProfileViewModels.swift
//  PlayArchive-iOS
//
//  Created by 水原　樹 on 2024/11/29.
//

import SwiftUI
import MapKit

class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile {
        didSet {
            // プロフィールが更新されたら保存
            saveProfile()
            // 通知を送信
            NotificationCenter.default.post(name: .profileUpdated, object: profile)
        }
    }
    
    init() {
        // 初期値として保存されているプロフィールを読み込む
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = savedProfile
        } else {
            // デフォルトのプロフィール
            self.profile = UserProfile(
                name: "",
                interests: [],
                status: "オンライン",
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )
        }
    }
    
    func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }
    }
}

// 通知用の拡張
extension Notification.Name {
    static let profileUpdated = Notification.Name("profileUpdated")
}
