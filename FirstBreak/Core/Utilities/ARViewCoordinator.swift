//
//  ARViewCoordinator.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import Foundation
import ARKit
import RealityKit
import SwiftUI

// ARViewのコーディネーター
class ARViewCoordinator: NSObject, ARSessionDelegate {
    var parent: ARProfileView
    @State private var selectedProfile: UserProfile?
    
    init(_ parent: ARProfileView) {
        self.parent = parent
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // アンカーの更新処理
    }
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = gesture.view as? ARView else { return }
        
        let location = gesture.location(in: arView)
        
        // RealityKitのraycastを使用
        let results = arView.raycast(from: location,
                                     allowing: .estimatedPlane,
                                     alignment: .any)
        
        if let firstResult = results.first {
            // タップ位置のワールド座標を取得
            let worldPosition = simd_make_float3(firstResult.worldTransform.columns.3)
            
            // タップ位置に最も近いエンティティを探す
            let entity = arView.scene.anchors.compactMap { anchor -> ProfileEntity? in
                guard let profileEntity = anchor.children.first as? ProfileEntity else { return nil }
                return profileEntity
            }.min { entity1, entity2 in
                // エンティティとタップ位置との距離を計算
                let distance1 = simd_distance(entity1.position, worldPosition)
                let distance2 = simd_distance(entity2.position, worldPosition)
                return distance1 < distance2
            }
            
            if let profileEntity = entity {
                // プロフィールが見つかった場合、詳細表示を表示
                selectedProfile = profileEntity.profile
                
                // UIKit環境でSwiftUIビューを表示
                let hostingController = UIHostingController(
                    rootView: ARProfileDetailView(profile: profileEntity.profile)
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(hostingController, animated: true)
                }
            }
        }
    }
}
