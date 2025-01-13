//
//  ProfileEntity.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit

class ProfileEntity: Entity, HasAnchoring {
    var profile: UserProfile
    var textEntity: Entity
    
    init(profile: UserProfile) {
        self.profile = profile
        self.textEntity = Entity()
        super.init()
        
        // テキストの生成と配置
        generateProfileText()
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    private func generateProfileText() {
        // プロフィール情報をModelEntityとして生成
        let profileText = """
        \(profile.name)
        \(profile.status)
        趣味: \(profile.interests.joined(separator: ", "))
        """
        
        // TextMeshComponent作成（RealityKitの制限により、実際にはMeshResourceを使用）
        // 注: これは概念的な実装で、実際にはさらに詳細な実装が必要です
    }
}
