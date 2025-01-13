//
//  ARProfileView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import SwiftUI
import ARKit
import RealityKit

struct ARProfileView: UIViewRepresentable {
    @EnvironmentObject var profileViewModel: ProfileViewModel  // 共有のViewModelを使用
    @StateObject private var bluetoothManager: BluetoothManager
    // ARSessionのステータスを保持
    @State private var isTracking: Bool = false
    
    
    init() {
        let tempProfile = UserProfile(
            name: "",
            interests: [],
            status: "オンライン",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        _bluetoothManager = StateObject(wrappedValue: BluetoothManager(myProfile: tempProfile))
    }
    

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARProfileView
        var profileObserver: NSObjectProtocol?
        
        init(_ parent: ARProfileView) {
            self.parent = parent
            super.init()
            
            // 初期プロフィールを設定
            parent.bluetoothManager.updateMyProfile(parent.profileViewModel.profile)
            
            // プロフィール更新の監視
            profileObserver = NotificationCenter.default.addObserver(
                forName: .profileUpdated,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let updatedProfile = notification.object as? UserProfile {
                    self?.parent.bluetoothManager.updateMyProfile(updatedProfile)
                }
            }
        }
        
        deinit {
            if let observer = profileObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR設定
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        // 環境光推定を有効化してよりリアルな表示に
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // ARSessionのステータス監視を追加
        arView.session.delegate = context.coordinator as? any ARSessionDelegate
        
        // デバッグ表示の追加
        let debugViewController = UIHostingController(rootView: DebugView(bluetoothManager: bluetoothManager))
        debugViewController.view.backgroundColor = .clear
        
        arView.addSubview(debugViewController.view)
        debugViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            debugViewController.view.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            debugViewController.view.trailingAnchor.constraint(equalTo: arView.leadingAnchor, constant: 300),
            debugViewController.view.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        print("更新開始: 検出ユーザー数 \(bluetoothManager.nearbyUsers.count)")
        print("デバイス位置情報数: \(bluetoothManager.devicePositions.count)")
        
        // 既存の表示をクリア
        uiView.scene.anchors.removeAll()
        
        // 検出されたユーザーごとにプロフィールを表示
        for user in bluetoothManager.nearbyUsers {
            print("ユーザー処理: \(user.name), ID: \(user.id)")
            
            if let devicePosition = bluetoothManager.devicePositions[user.id] {
                print("デバイス位置情報あり - 距離: \(devicePosition.distance)m, RSSI: \(devicePosition.rssi)")
                
                // 古い位置情報は使用しない
                let timeSinceUpdate = Date().timeIntervalSince(devicePosition.lastUpdate)
                if timeSinceUpdate > 5.0 { // 5秒以上経過した情報は使用しない
                    print("古い位置情報のためスキップ: \(timeSinceUpdate)秒経過")
                    continue
                }
                
                let anchor = createPositionedSpeechBubble(
                    for: user,
                    position: devicePosition,
                    cameraTransform: uiView.session.currentFrame?.camera.transform ?? .init()
                )
                uiView.scene.addAnchor(anchor)
                print("アンカー追加完了: \(user.name)")
            } else {
                print("デバイス位置情報なし: \(user.name)")
            }
        }
    }
    
    private func createPositionedSpeechBubble(
        for user: UserProfile,
        position: BluetoothManager.DevicePosition,
        cameraTransform: simd_float4x4
    ) -> AnchorEntity {
        // 距離とRSSIに基づいて位置を計算
        let distance = Float(position.distance)
        let angle = Float(position.angle)
        
        // デバイスの3D位置を計算
        let devicePosition = simd_float3(
            distance * sin(angle),
            0.1,  // 高さは固定
            -distance * cos(angle)
        )
        
        // カメラの向きを考慮した位置調整
        let cameraRotation = simd_quatf(cameraTransform)
        let adjustedPosition = cameraRotation.act(devicePosition)
        
        let anchor = AnchorEntity(world: adjustedPosition)
        
        // 吹き出しの作成
        let bubbleEntity = createBubbleEntity(for: user, position: position)
        
        // 信号強度に基づいて透明度を調整
        let alpha = calculateAlpha(from: position.rssi)
        // エラーがある部分を修正します
        if var materials = bubbleEntity.model?.materials as? [SimpleMaterial] {
            materials = materials.map { material in
                var newMaterial = material
                // 修正後：正しいbaseColorの設定方法
                newMaterial.baseColor = MaterialColorParameter.color(UIColor(white: 1.0, alpha: CGFloat(alpha)))
                return newMaterial
            }
            bubbleEntity.model?.materials = materials
        }
        
        // カメラ位置の取得
        let cameraPosition = simd_float3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // 吹き出しを常にカメラの方を向くように設定
        bubbleEntity.look(
            at: cameraPosition,
            from: adjustedPosition,
            relativeTo: nil
        )
        
        anchor.addChild(bubbleEntity)
        return anchor
    }
    
    private func createBubbleEntity(for user: UserProfile, position: BluetoothManager.DevicePosition) -> ModelEntity {
        // 吹き出しの背景を大きくする
        let bubbleMesh = MeshResource.generatePlane(
            width: 0.3,  // 幅を広げる
            depth: 0.2   // 高さを増やす
        )
        
        let bubbleMaterial = SimpleMaterial(
            color: UIColor(white: 1.0, alpha: 0.8),
            isMetallic: false
        )
        
        let bubbleEntity = ModelEntity(
            mesh: bubbleMesh,
            materials: [bubbleMaterial]
        )
        
        // テキストを大きくして見やすくする
        let displayText = """
        名前: \(user.name)
        距離: \(String(format: "%.1fm", position.distance))
        信号強度: \(position.rssi)dBm
        """
        
        let nameText = generateTextEntity(
            text: displayText,
            color: .black,
            size: 0.02  // サイズを大きくする
        )
        nameText.position = [0, 0, 0.001]
        
        bubbleEntity.addChild(nameText)
        
        return bubbleEntity
    }
    
    // 信号強度から透明度を計算
    private func calculateAlpha(from rssi: Int) -> Float {
        // -30dBm以上を1.0、-90dBm以下を0.3として正規化
        let normalizedRSSI = Float(rssi + 90) / 60.0
        return max(0.3, min(1.0, normalizedRSSI))
    }
    
    private func createSpeechBubble(for user: UserProfile, at index: Int) -> AnchorEntity {
        let xOffset = Float(index) * 0.3  // 横の間隔を縮小
        let anchor = AnchorEntity(world: [xOffset, 0.1, -0.5])  // より近くに表示
        
        // 吹き出しの背景
        let bubbleMesh = MeshResource.generatePlane(
            width: 0.15,  // 幅を小さく
            depth: 0.1    // 高さも小さく
        )
        
        // 背景のマテリアル（半透明の白）
        let bubbleMaterial = SimpleMaterial(
            color: .white.withAlphaComponent(0.8),
            isMetallic: false
        )
        
        // 吹き出しの形状
        let bubbleEntity = ModelEntity(
            mesh: bubbleMesh,
            materials: [bubbleMaterial]
        )
        
        
        
        // テキスト表示
        let nameText = generateTextEntity(
            text: user.name,
            color: .black,
            size: 0.015
        )
        nameText.position = [0, 0.02, 0.001]
        
//        let statusText = generateTextEntity(
//            text: user.status,
//            color: .blue,
//            size: 0.012
//        )
//        statusText.position = [0, -0.02, 0.001]
        
        // すべての要素を追加
        bubbleEntity.addChild(nameText)
//        bubbleEntity.addChild(statusText)
        
        // 三角形の尖りを追加（吹き出しの下部）
        let triangleMesh = MeshResource.generatePlane(
            width: 0.02,
            depth: 0.02
        )
        let triangleEntity = ModelEntity(
            mesh: triangleMesh,
            materials: [bubbleMaterial]
        )
        triangleEntity.position = [0, -0.06, 0]
        triangleEntity.orientation = simd_quatf(angle: .pi / 4, axis: [0, 0, 1])
        
        // 吹き出しを常にカメラの方を向くようにする
        bubbleEntity.look(
            at: [0, 0, 0],
            from: bubbleEntity.position,
            relativeTo: nil
        )
        
        // アンカーに追加
        anchor.addChild(bubbleEntity)
        anchor.addChild(triangleEntity)
        
        return anchor
    }
    
    private func generateTextEntity(text: String, color: UIColor, size: Float) -> ModelEntity {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .boldSystemFont(ofSize: 1),  // フォントを太めに
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let textMaterial = SimpleMaterial(
            color: color,
            isMetallic: false
        )
        
        return ModelEntity(
            mesh: textMesh,
            materials: [textMaterial]
        )
    }
}

// ARSessionDelegateの追加
extension ARProfileView.Coordinator: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // トラッキングステータスの更新
        parent.isTracking = frame.camera.trackingState == .normal
    }
}

#Preview {
    ARProfileView()
}
