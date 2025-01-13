//
//  ContentView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import SwiftUI
import CoreBluetooth
import SwiftUI
import ARKit
import RealityKit

// ARプロフィール表示用のView
struct ContentARProfileView: View {
    let profile: Profile
    @StateObject private var arController = ContentARViewController()
    
    var body: some View {
        ZStack {
            // AR View
            ContentARViewContainer(profile: profile, arController: arController)
                .edgesIgnoringSafeArea(.all)
            
            // コントロールUI
            VStack {
                Spacer()
                
                Button(action: {
                    arController.addProfileCard(profile: profile)
                }) {
                    Text("プロフィールを表示")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom)
            }
        }
    }
}

// AR View Container
struct ContentARViewContainer: UIViewRepresentable {
    let profile: Profile
    let arController: ContentARViewController
    
    func makeUIView(context: Context) -> ARView {
        let arView = arController.arView
        
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// AR Controller
class ContentARViewController: NSObject, ObservableObject {
    let arView = ARView(frame: .zero)
    @Published var isTrackingBody = false
    
    override init() {
        super.init()
        setupAR()
    }
    
    func setupAR() {
        // World Trackingの設定を変更
        let config = ARWorldTrackingConfiguration()
        
        // 人物追跡を有効化
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics = [.personSegmentationWithDepth]
        }
        
        // 平面検出を有効化
        config.planeDetection = [.horizontal, .vertical]
        
        // 環境テクスチャマッピングを有効化
        config.environmentTexturing = .automatic
        
        // 設定を適用
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        arView.session.delegate = self
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        print("Tapped at: \(gesture.location(in: arView))")
    }
    
    func addProfileCard(profile: Profile) {
        // 既存のカードを削除
        arView.scene.anchors.forEach { anchor in
            if anchor.name == "profileCard" {
                arView.scene.removeAnchor(anchor)
            }
        }
        
        guard let frame = arView.session.currentFrame else { return }
        
        // 画面上部中央の位置を計算（人物の頭上を想定）
        let screenPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY - 300)
        
        // スクリーン座標から3D空間へのレイキャスト
        guard let query = arView.makeRaycastQuery(
            from: screenPoint,
            allowing: .estimatedPlane,
            alignment: .vertical
        ) else { return }
        
        guard let result = arView.session.raycast(query).first else { return }
        
        // アンカーエンティティの作成
        let anchorEntity = AnchorEntity(world: result.worldTransform)
        
        // カードエンティティの作成
        let cardEntity = createProfileCardEntity(profile: profile)
        cardEntity.name = "profileCard"
        
        // カードをカメラに向ける
        let cameraPosition = simd_make_float3(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        
        let cardPosition = simd_make_float3(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y + 0.2, // 20cm上に調整
            result.worldTransform.columns.3.z
        )
        
        cardEntity.look(at: cameraPosition,
                        from: cardPosition,
                        relativeTo: nil as Entity?)
        
        // カードをアンカーに追加
        anchorEntity.addChild(cardEntity)
        
        // シーンにアンカーを追加
        arView.scene.addAnchor(anchorEntity)
    }
    
    private func createProfileCardEntity(profile: Profile) -> Entity {
        let cardEntity = ModelEntity()
        
        // 背景パネル
        let panel = ModelEntity(
            mesh: .generatePlane(width: 0.3, depth: 0.15),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.8), isMetallic: false)]
        )
        panel.position.z = 0.01
        
        // テキストの生成とサイズ調整
        let nameText = createText("名前: \(profile.name)", y: 0.04, scale: 0.02)
        let ageText = createText("年齢: \(profile.age)歳", y: 0, scale: 0.02)
        let hobbyText = createText("趣味: \(profile.hobby)", y: -0.04, scale: 0.02)
        
        // テキストの向きを調整
        [nameText, ageText, hobbyText].forEach { textEntity in
            textEntity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        }
        
        // カードに要素を追加
        cardEntity.addChild(panel)
        cardEntity.addChild(nameText)
        cardEntity.addChild(ageText)
        cardEntity.addChild(hobbyText)
        
        return cardEntity
    }
    
    private func createText(_ text: String, y: Float, scale: Float) -> ModelEntity {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let textEntity = ModelEntity(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .black, isMetallic: false)]
        )
        
        // テキストの位置とサイズを設定
        textEntity.position = SIMD3<Float>(0, y, 0.001)
        textEntity.scale = SIMD3<Float>(scale, scale, scale)
        
        return textEntity
    }
}
// プロフィール情報を表すモデル
struct Profile: Codable {
    var name: String
    var age: Int
    var hobby: String
}

// ARSessionDelegateの実装
extension ContentARViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 検出状態をより詳細にチェック
        DispatchQueue.main.async {
            let isTracking = frame.anchors.contains { anchor in
                anchor is ARPlaneAnchor || frame.detectedBody != nil
            }
            self.isTrackingBody = isTracking
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        // 人物検出時の処理が必要な場合はここに追加
    }
}

// Bluetoothの通信を管理するクラス
class ContentBluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var discoveredPeripheral: CBPeripheral?
    
    private var profileCharacteristic: CBMutableCharacteristic?
    private var currentProfileData: Data?
    
    // UUIDを修正（カスタムUUIDを使用）
    private let serviceUUID = CBUUID(string: "A1B2C3D4-1234-5678-9ABC-DEF012345678")
    private let characteristicUUID = CBUUID(string: "B1B2C3D4-1234-5678-9ABC-DEF012345678")
    
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var connectedProfile: Profile?
    @Published var bluetoothStatus: String = "準備中"
    
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // スキャンを開始
    func startScanning() {
        print("スキャンを開始")
        guard centralManager.state == .poweredOn else {
            bluetoothStatus = "Bluetoothが無効です"
            return
        }
        isScanning = true
        bluetoothStatus = "スキャン中..."
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    // アドバタイズを開始
    func startAdvertising(profile: Profile) {
        print("アドバタイズを開始")
        guard peripheralManager.state == .poweredOn else {
            bluetoothStatus = "Bluetoothが無効です"
            return
        }
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // プロフィールデータをエンコード
        guard let profileData = try? JSONEncoder().encode(profile) else {
            bluetoothStatus = "プロフィールのエンコードに失敗"
            return
        }
        currentProfileData = profileData
        
        // Characteristicの作成を修正
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .notify],
            value: nil,  // 初期値はnilに設定
            permissions: .readable
        )
        
        profileCharacteristic = characteristic
        service.characteristics = [characteristic]
        peripheralManager.add(service)
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "ProfileExchange"
        ]
        
        isAdvertising = true
        bluetoothStatus = "プロフィール共有中..."
        peripheralManager.startAdvertising(advertisementData)
    }
    
    // スキャンとアドバタイズを停止
    func stopAll() {
        centralManager.stopScan()
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        isScanning = false
        isAdvertising = false
        bluetoothStatus = "停止中"
    }
}

// Central側の delegate 拡張
extension ContentBluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Central manager is powered on")
            bluetoothStatus = "Bluetooth準備完了"
        case .poweredOff:
            bluetoothStatus = "Bluetoothがオフです"
            stopAll()
        case .unauthorized:
            bluetoothStatus = "Bluetooth権限がありません"
            stopAll()
        default:
            bluetoothStatus = "Bluetoothが利用できません"
            stopAll()
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        print("デバイスを発見: \(peripheral.name ?? "Unknown")")
        bluetoothStatus = "デバイスを発見"
        
        discoveredPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("接続成功")
        bluetoothStatus = "接続成功"
        peripheral.discoverServices([serviceUUID])
    }
}

// Peripheral側の delegate 拡張
extension ContentBluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("Peripheral manager is powered on")
        } else {
            stopAll()
        }
    }
    
    // 読み取りリクエストに対する応答を追加
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if let characteristic = profileCharacteristic,
           request.characteristic.uuid == characteristic.uuid,
           let data = currentProfileData {
            request.value = data
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .unlikelyError)
        }
    }
}
// Peripheral delegate 拡張
extension ContentBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value,
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else { return }
        
        DispatchQueue.main.async {
            self.connectedProfile = profile
        }
    }
}

// ARProfileViewWithBluetooth
struct ARProfileViewWithBluetooth: View {
    @ObservedObject var bluetoothManager: ContentBluetoothManager
    @Binding var myProfile: Profile
    @Binding var showARView: Bool
    @StateObject private var arController = ContentARViewController()
    
    var body: some View {
        ZStack {
            ContentARViewContainer(profile: bluetoothManager.connectedProfile ?? myProfile, arController: arController)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // ステータスメッセージ
                if !arController.isTrackingBody {
                    Text("人物を検出中...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                } else {
                    Text("検出しました！")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green.opacity(0.5))
                        .cornerRadius(10)
                        .transition(.opacity) // フェードエフェクトを追加
                }
                
                Spacer()
                
                VStack(spacing: 10) {
                    HStack(spacing: 20) {
                        Button(action: {
                            bluetoothManager.startScanning()
                        }) {
                            Text("Scan")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            bluetoothManager.startAdvertising(profile: myProfile)
                        }) {
                            Text("Share Profile")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                    
                    // プロフィール表示ボタン（常に表示）
                    Button(action: {
                        arController.addProfileCard(profile: bluetoothManager.connectedProfile ?? myProfile)
                    }) {
                        Text("プロフィールを表示")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showARView = false
                    }) {
                        Text("戻る")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
            }
        }
    }
}
// メインビュー
struct ContentView: View {
    @StateObject private var bluetoothManager = ContentBluetoothManager()
    @State private var myProfile = Profile(name: "", age: 0, hobby: "")
    @State private var isShowingProfileInput = false
    @State private var showARView = false
    
    var body: some View {
        VStack(spacing: 20) {
            // ステータス表示
            Text(bluetoothManager.bluetoothStatus)
                .foregroundColor(.blue)
                .padding()
            
            // プロフィール入力フォーム（変更なし）
            VStack(alignment: .leading) {
                Text("My Profile")
                    .font(.headline)
                
                TextField("Name", text: $myProfile.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Age", value: $myProfile.age, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                
                TextField("Hobby", text: $myProfile.hobby)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            
            // 接続ボタン群
            VStack(spacing: 15) {
                HStack(spacing: 20) {
                    Button(action: {
                        bluetoothManager.startScanning()
                    }) {
                        Text("Scan")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        bluetoothManager.startAdvertising(profile: myProfile)
                    }) {
                        Text("Share Profile")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                
                // AR表示ボタン（常に表示）
                Button(action: {
                    showARView = true
                }) {
                    Text("ARで表示")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
            }
            
            // 受信したプロフィール表示（変更なし）
            if let connectedProfile = bluetoothManager.connectedProfile {
                VStack(alignment: .leading) {
                    Text("Connected Profile")
                        .font(.headline)
                    
                    Text("Name: \(connectedProfile.name)")
                    Text("Age: \(connectedProfile.age)")
                    Text("Hobby: \(connectedProfile.hobby)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .onDisappear {
            bluetoothManager.stopAll()
        }
        .fullScreenCover(isPresented: $showARView) {
            ARProfileViewWithBluetooth(
                bluetoothManager: bluetoothManager,
                myProfile: $myProfile,
                showARView: $showARView
            )
        }
    }
}

#Preview {
    ContentView()
}
