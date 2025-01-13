//
//  SpotifyARView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2025/01/04.
//


// AppDelegate.swift
import UIKit
import CoreBluetooth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

// MARK: - Constants and Models
struct BluetoothConstants {
    // カスタムサービスUUID（実際の実装時には新しいUUIDを生成してください）
    static let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-47A8-B9C0-D1E2F3A4B5C6")
    static let characteristicUUID = CBUUID(string: "B1A2C3D4-E5F6-47A8-B9C0-D1E2F3A4B5C6")
}

struct SpotifyPlaybackInfo: Codable {
    let trackName: String
    let artistName: String
    let albumArtURL: String
}

class SpotifyBluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("📱 Peripheral マネージャーの状態更新: \(peripheral.state.rawValue)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        print("📱 読み取りリクエストを受信")
        
        if let value = characteristic?.value {
            request.value = value
            peripheral.respond(to: request, withResult: .success)
            print("✅ 読み取りリクエストに応答")
        } else {
            peripheral.respond(to: request, withResult: .unlikelyError)
            print("❌ 読み取りリクエストに失敗")
        }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        print("📱 書き込みリクエストを受信")
        
        for request in requests {
            if let data = request.value {
                characteristic?.value = data
                peripheral.respond(to: request, withResult: .success)
                print("✅ 書き込みリクエストに応答")
            } else {
                peripheral.respond(to: request, withResult: .unlikelyError)
                print("❌ 書き込みリクエストに失敗")
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("📱 Central マネージャーの状態更新: \(central.state.rawValue)")
        if central.state == .poweredOn {
            startScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // すでに接続済みのデバイスは無視
        guard peripheral.state != .connected else {
            return
        }
        
        if !discoveredPeripherals.contains(peripheral) {
            print("🔍 新しいデバイスを発見: \(peripheral.identifier)")
            discoveredPeripherals.append(peripheral)
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("📱 デバイス切断: \(peripheral.identifier)")
        if let index = discoveredPeripherals.firstIndex(of: peripheral) {
            discoveredPeripherals.remove(at: index)
        }
        print("🔄 再接続を試行")
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("❌ 接続失敗: \(peripheral.identifier)")
        if let error = error {
            print("エラー詳細: \(error.localizedDescription)")
        }
    }
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("✅ デバイスに接続完了: \(peripheral.identifier)")
        peripheral.delegate = self
        // サービスの検出を開始
        print("🔍 サービスの検出を開始")
        peripheral.discoverServices([BluetoothConstants.serviceUUID])
    }
    
    
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    private var discoveredPeripherals: [CBPeripheral] = []
    var onPlaybackInfoReceived: ((SpotifyPlaybackInfo) -> Void)?
    
    // デバッグ用のフラグ
    private var isAdvertising = false
    private var isScanning = false
    
    override init() {
        super.init()
        setupManagers()
    }
    
    private func setupManagers() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func startAdvertising(with playbackInfo: SpotifyPlaybackInfo) {
        print("🎵 広告開始: \(playbackInfo.trackName)")
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            print("❌ Peripheral マネージャーが準備できていません")
            return
        }
        
        // 既存のサービスを削除
        peripheralManager.removeAllServices()
        
        // 特性の作成 - プロパティを修正
        characteristic = CBMutableCharacteristic(
            type: BluetoothConstants.characteristicUUID,
            properties: [.read, .notify, .indicate], // .writeを削除し、.indicateを追加
            value: nil,
            permissions: [.readable]
        )
        
        let service = CBMutableService(type: BluetoothConstants.serviceUUID, primary: true)
        service.characteristics = [characteristic].compactMap { $0 }
        
        peripheralManager.add(service)
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BluetoothConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: "SpotifyAR"
        ])
        
        // 再生情報を更新
        updatePlaybackInfo(playbackInfo)
        isAdvertising = true
        print("📢 アドバタイズ開始完了")
    }

    
    private func updatePlaybackInfo(_ playbackInfo: SpotifyPlaybackInfo) {
        guard let characteristic = characteristic else {
            print("❌ Characteristic が設定されていません")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(playbackInfo)
            // 特性の値を直接設定
            (characteristic as! CBMutableCharacteristic).value = data
            
            peripheralManager?.updateValue(
                data,
                for: characteristic,
                onSubscribedCentrals: nil
            )
            print("✅ 再生情報を更新: \(playbackInfo.trackName)")
        } catch {
            print("❌ 再生情報のエンコードに失敗: \(error)")
        }
    }
    
    func startScanning() {
        print("🔍 スキャン開始")
        guard let centralManager = centralManager,
              centralManager.state == .poweredOn else {
            print("❌ Central マネージャーが準備できていません")
            return
        }
        
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [BluetoothConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    // デバッグ用のメソッド
    func printStatus() {
        print("=== Bluetooth Status ===")
        print("Central Manager State: \(centralManager?.state.rawValue ?? -1)")
        print("Peripheral Manager State: \(peripheralManager?.state.rawValue ?? -1)")
        print("Is Advertising: \(isAdvertising)")
        print("Is Scanning: \(isScanning)")
        print("Discovered Peripherals: \(discoveredPeripherals.count)")
        print("=====================")
    }
    
}

extension SpotifyBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else {
            print("❌ サービス検出エラー: \(error!)")
            return
        }
        
        guard let services = peripheral.services else {
            print("❌ サービスが見つかりません")
            return
        }
        
        print("🔍 サービス検出完了: \(services.count)個")
        for service in services {
            print("👉 サービスを検出: \(service.uuid)")
            peripheral.discoverCharacteristics([BluetoothConstants.characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            print("❌ キャラクタリスティック検出エラー: \(error!)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ キャラクタリスティックが見つかりません")
            return
        }
        
        print("🔍 キャラクタリスティック検出完了: \(characteristics.count)個")
        for characteristic in characteristics {
            if characteristic.uuid == BluetoothConstants.characteristicUUID {
                print("👉 音楽情報のキャラクタリスティックを検出")
                // 値の読み取りと通知を有効化
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ Notify設定エラー: \(error)")
            return
        }
        print("✅ Notify設定完了: \(characteristic.isNotifying)")
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        print("📱 データ受信")
        if let error = error {
            print("❌ データ受信エラー: \(error)")
            return
        }
        
        guard let data = characteristic.value else {
            print("❌ データが空です")
            return
        }
        
        do {
            let playbackInfo = try JSONDecoder().decode(SpotifyPlaybackInfo.self, from: data)
            print("✅ 相手の曲データを受信: \(playbackInfo.trackName)")
            DispatchQueue.main.async { [weak self] in
                self?.onPlaybackInfoReceived?(playbackInfo)
            }
        } catch {
            print("❌ データのデコード失敗: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("📝 受信データ: \(dataString)")
            }
        }
    }
}


// ARSpotifyView.swift
import SwiftUI

struct ARSpotifyView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        let viewController = ViewController()
        
        NotificationCenter.default.addObserver(
            forName: .spotifyCallback,
            object: nil,
            queue: .main
        ) { [weak viewController] notification in
            if let url = notification.object as? URL,
               let viewController = viewController {
                viewController.handleURL(url)
            }
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}

// ViewController.swift
import UIKit
import ARKit
import SceneKit
import SpotifyiOS

class ViewController: UIViewController {
    private var sceneView: ARSCNView!
    private var spotifyController: SPTSessionManager!
    private var configuration: SPTConfiguration!
    private var appRemote: SPTAppRemote?
    private var bluetoothManager: SpotifyBluetoothManager!
    
    private var currentTrackNode: SCNNode?  // 自分の音楽情報用
    private var otherTrackNode: SCNNode?   // 相手の音楽情報用
    
    // Spotify APIの設定
    private let clientID = "8689a3c59f064e31b759b6510a41529d"
    private let redirectURL = URL(string: "firstbreak://callback")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBluetooth()
        setupSpotify()
        addDebugButton()  // デバッグ用ボタンを追加
        
        
        // Bluetoothの状態が変化したときの通知を登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bluetoothStateChanged),
            name: NSNotification.Name(rawValue: "BluetoothStateChanged"),
            object: nil
        )
    }
    
    @objc private func bluetoothStateChanged(_ notification: Notification) {
        if let state = notification.object as? Int {
            print("Bluetooth状態変更: \(state)")
        }
    }
    
    func addDebugButton() {
        let button = UIButton(frame: CGRect(x: 20, y: 40, width: 120, height: 40))
        button.setTitle("Debug Info", for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)
        view.addSubview(button)
    }
    
    @objc private func debugButtonTapped() {
        bluetoothManager.printStatus()
    }
    
    private func setupBluetooth() {
        bluetoothManager = SpotifyBluetoothManager()
        bluetoothManager.onPlaybackInfoReceived = { [weak self] playbackInfo in
            print("🎵 AR表示更新開始: \(playbackInfo.trackName)")
            self?.updateARDisplayFromBluetooth(with: playbackInfo)
        }
        bluetoothManager.startScanning()
    }
    

    // 自分が現在Spotifyで聴いている曲の情報を、Bluetooth経由で他のデバイスに共有するための関数
    private func sharePlaybackInfo(from playerState: SPTAppRemotePlayerState) {
        appRemote?.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 300, height: 300)) { [weak self] (result, error) in
            if let image = result as? UIImage {
                // imageIdentifierから不要な部分を削除
                var imageId = playerState.track.imageIdentifier ?? ""
                if imageId.hasPrefix("spotify:image:") {
                    imageId = String(imageId.dropFirst("spotify:image:".count))
                }
                
                let albumArtURL = "https://i.scdn.co/image/\(imageId)"
                
                let playbackInfo = SpotifyPlaybackInfo(
                    trackName: playerState.track.name,
                    artistName: playerState.track.artist.name,
                    albumArtURL: albumArtURL
                )
                self?.bluetoothManager.startAdvertising(with: playbackInfo)
                print("共有するアルバムURL: \(albumArtURL)")
            }
        }
    }
    // 自分の聴いてる曲の表示
    private func updateARDisplay(with playerState: SPTAppRemotePlayerState) {
        print("AR表示更新開始（自分の曲）")
        currentTrackNode?.removeFromParentNode()
        
        // テキストノードの作成
        let trackInfo = "今聴いている曲:\n\(playerState.track.name)\nアーティスト名\(playerState.track.artist.name)"
        let textGeometry = SCNText(string: trackInfo, extrusionDepth: 1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.002, 0.002, 0.002)
        
        guard let camera = sceneView.pointOfView else { return }
        let position = SCNVector3(-0.3, -0.2, -0.8)
        textNode.position = camera.convertPosition(position, to: nil)
        
        sceneView.scene.rootNode.addChildNode(textNode)
        currentTrackNode = textNode
        
        // アートワーク取得
        // // 自分の音楽の場合は、SpotifyのAPIから直接画像を取得している
        appRemote?.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 300, height: 300)) { [weak self] (result, error) in
            if let image = result as? UIImage {
                print("画像取得成功: \(image.size)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let albumNode = self.createAlbumArtworkNode(with: image)
                    
                    // アートワークの位置も左に揃える
                    let artworkPosition = SCNVector3(-0.1, 0.1, -0.8)
                    albumNode.position = camera.convertPosition(artworkPosition, to: nil)
                    
                    self.sceneView.scene.rootNode.addChildNode(albumNode)
                    print("アートワーク配置: \(albumNode.worldPosition)")
                }
            }
        }
    }
    
    // 相手の聴いている曲
    private func updateARDisplayFromBluetooth(with playbackInfo: SpotifyPlaybackInfo) {
        print("AR表示更新開始（相手の曲）")
        print("受信したアルバムURL: \(playbackInfo.albumArtURL)") // デバッグ用
        otherTrackNode?.removeFromParentNode()
        
        let trackInfo = "相手の聴いてる曲名:\n\(playbackInfo.trackName)\nアーティスト名\(playbackInfo.artistName)"
        let textGeometry = SCNText(string: trackInfo, extrusionDepth: 1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.green
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.002, 0.002, 0.002)
        
        guard let camera = sceneView.pointOfView else { return }
        let position = SCNVector3(0.3, -0.2, -0.8)
        textNode.position = camera.convertPosition(position, to: nil)
        
        sceneView.scene.rootNode.addChildNode(textNode)
        otherTrackNode = textNode
        
        // ローカルファイルURLから画像を読み込む
        // 画像URLから画像を非同期で取得
        if let url = URL(string: playbackInfo.albumArtURL) {
            print("画像の取得を試行: \(url)")
            
            let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
                if let error = error {
                    print("画像取得エラー: \(error)")
                    return
                }
                
                guard let imageData = data,
                      let image = UIImage(data: imageData) else {
                    print("画像データの変換に失敗")
                    return
                }
                
                print("画像取得成功: \(image.size)")
                
                DispatchQueue.main.async {
                    guard let self = self,
                          let camera = self.sceneView.pointOfView else { return }
                    
                    let albumNode = self.createAlbumArtworkNode(with: image)
                    let artworkPosition = SCNVector3(0.5, 0.1, -0.8)
                    albumNode.position = camera.convertPosition(artworkPosition, to: nil)
                    
                    let constraint = SCNBillboardConstraint()
                    constraint.freeAxes = SCNBillboardAxis.all
                    albumNode.constraints = [constraint]
                    
                    self.sceneView.scene.rootNode.addChildNode(albumNode)
                    print("相手の曲のアートワーク配置完了")
                }
            }
            task.resume()
        }
    }
    
//    // 相手のアルバム画面固定
//    private func updateARDisplayFromBluetooth(with playbackInfo: SpotifyPlaybackInfo) {
//        print("AR表示更新開始（相手の曲）")
//        otherTrackNode?.removeFromParentNode()
//        
//        // カメラに追従するノードを作成
//        let cameraNode = SCNNode()
//        
//        // テキストノードの作成
//        let trackInfo = "相手の聴いてる曲名:\n\(playbackInfo.trackName)\nアーティスト名\(playbackInfo.artistName)"
//        let textGeometry = SCNText(string: trackInfo, extrusionDepth: 1)
//        textGeometry.firstMaterial?.diffuse.contents = UIColor.green
//        textGeometry.firstMaterial?.isDoubleSided = true
//        
//        let textNode = SCNNode(geometry: textGeometry)
//        textNode.scale = SCNVector3(0.002, 0.002, 0.002)
//        
//        // テキストをカメラの前に固定
//        textNode.position = SCNVector3(0, 0, -1.0) // カメラの1m前
//        
//        // カメラノードにテキストを追加
//        cameraNode.addChildNode(textNode)
//        
//        // カメラノードをシーンのカメラに追加
//        guard let camera = sceneView.pointOfView else { return }
//        camera.addChildNode(cameraNode)
//        otherTrackNode = cameraNode
//        
//        // アルバムアートの表示
//        if let url = URL(string: playbackInfo.albumArtURL) {
//            print("画像の取得を試行: \(url)")
//            
//            URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
//                guard let self = self,
//                      let imageData = data,
//                      let image = UIImage(data: imageData) else {
//                    print("画像データの変換に失敗")
//                    return
//                }
//                
//                DispatchQueue.main.async {
//                    let albumNode = self.createAlbumArtworkNode(with: image)
//                    
//                    // アルバムアートもカメラの前に固定
//                    albumNode.position = SCNVector3(0, 0.2, -1.0) // テキストの少し上
//                    
//                    // アルバムアートもカメラノードに追加
//                    cameraNode.addChildNode(albumNode)
//                    print("相手の曲のアートワーク配置完了")
//                }
//            }.resume()
//        }
//        
//        print("✅ 相手の曲情報を表示: \(playbackInfo.trackName)")
//    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkCameraPermission()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView?.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        currentTrackNode?.removeFromParentNode()
        currentTrackNode = nil
    }
    
    private func setupSpotify() {
        print("Spotify設定開始")
        configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        

        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.delegate = self
        
        spotifyController = SPTSessionManager(configuration: configuration, delegate: self)
        
        print("認証開始")
        let scopes: SPTScope = [.userReadCurrentlyPlaying, .userReadPlaybackState, .streaming, .appRemoteControl]
        spotifyController.initiateSession(with: scopes, options: .default, campaign: "")
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupARKit()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupARKit()
                    }
                }
            }
        default:
            showCameraPermissionAlert()
        }
    }
    
    private func setupARKit() {
        sceneView = ARSCNView(frame: view.bounds)
        view.addSubview(sceneView)
        
        sceneView.delegate = self        // これを追加
        sceneView.session.delegate = self  // これを追加
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isAutoFocusEnabled = true
        
        // カメラの初期化を待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sceneView.session.run(configuration)
        }
    }
    
    func handleURL(_ url: URL) {
        spotifyController?.application(UIApplication.shared, open: url)
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "カメラの権限が必要です",
            message: "設定からカメラの権限を許可してください",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "設定を開く", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        present(alert, animated: true)
    }
    
    private func handleSpotifyError(_ error: Error) {
        let alert = UIAlertController(
            title: "Spotify接続エラー",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateNowPlaying() {
        print("updateNowPlaying開始")
        appRemote?.playerAPI?.subscribe(toPlayerState: { [weak self] (result, error) in
            if let error = error {
                print("PlayerState取得エラー: \(error)")
                return
            }
            
            if let state = result as? SPTAppRemotePlayerState {
                print("State conversion succeeded")
                DispatchQueue.main.async {
                    self?.updateARDisplay(with: state)
                    // Bluetooth経由で情報を共有
                    self?.sharePlaybackInfo(from: state)
                }
            } else {
                print("PlayerState変換失敗")
                self?.appRemote?.playerAPI?.getPlayerState { [weak self] (result, error) in
                    if let error = error {
                        print("GetPlayerState error: \(error)")
                        return
                    }
                    
                    if let state = result as? SPTAppRemotePlayerState {
                        print("GetPlayerState succeeded")
                        DispatchQueue.main.async {
                            self?.updateARDisplay(with: state)
                            // Bluetooth経由で情報を共有
                            self?.sharePlaybackInfo(from: state)
                        }
                    }
                }
            }
        })
    }
    
    
    
    private func createAlbumArtworkNode(with image: UIImage) -> SCNNode {
        print("アルバムアートワークノード作成開始")
        
        let plane = SCNPlane(width: 0.4, height: 0.4)  // サイズを調整
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.isDoubleSided = true
        material.lightingModel = .constant
        
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        
        // ビルボーディング設定
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = SCNBillboardAxis.all
        node.constraints = [constraint]
        
        print("アートワークノード作成完了")
        return node
    }
    
    private func createAlbumArtworkNode(with imageURL: String) -> SCNNode {
        let plane = SCNPlane(width: 0.2, height: 0.2)
        let material = SCNMaterial()
        
        if let url = URL(string: imageURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let imageData = data, let image = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        material.diffuse.contents = image
                    }
                }
            }.resume()
        }
        
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 0.15, 0)
        
        return node
    }
}

extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARセッションエラー: \(error.localizedDescription)")

    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("ARセッションが中断されました")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("ARセッションの中断が終了しました")
        sceneView.session.run(sceneView.session.configuration!,
                              options: [.resetTracking, .removeExistingAnchors])
    }
}

extension ViewController: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        print("セッション開始成功: トークン取得")
        DispatchQueue.main.async { [weak self] in
            print("AppRemoteの接続設定開始")
            self?.appRemote?.connectionParameters.accessToken = session.accessToken
            print("Spotify接続開始")
            
            // Spotifyアプリが起動しているか確認
            if UIApplication.shared.canOpenURL(URL(string: "spotify:")!) {
                self?.appRemote?.connect()
            } else {
                print("Spotifyアプリが見つかりません")
                // エラーアラートを表示
                let alert = UIAlertController(
                    title: "Spotifyアプリが必要です",
                    message: "Spotifyアプリをインストールしてください",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "App Storeを開く", style: .default) { _ in
                    UIApplication.shared.open(URL(string: "itms-apps://itunes.apple.com/app/spotify")!)
                })
                self?.present(alert, animated: true)
            }
        }
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("Spotify認証エラー: \(error.localizedDescription)")
        handleSpotifyError(error)
    }
}

extension ViewController: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("AppRemote接続成功")
        DispatchQueue.main.async { [weak self] in
            self?.appRemote = appRemote
            if appRemote.isConnected {
                print("Spotifyに接続済み - 曲情報取得開始")
                self?.updateNowPlaying()
            } else {
                print("Spotify未接続 - アプリを起動")
                UIApplication.shared.open(URL(string: "spotify:")!) { success in
                    if success {
                        print("Spotifyアプリ起動成功")
                        self?.appRemote?.connect()
                    }
                }
            }
        }
    }
    
    // メソッド名を修正
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("AppRemote接続エラー: \(error?.localizedDescription ?? "不明なエラー")")
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Spotify接続エラー",
                message: "Spotifyアプリが起動しているか確認してください",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "再試行", style: .default) { _ in
                self?.appRemote?.connect()
            })
            alert.addAction(UIAlertAction(title: "Spotifyを開く", style: .default) { _ in
                UIApplication.shared.open(URL(string: "spotify:")!)
            })
            self?.present(alert, animated: true)
        }
    }
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("AppRemote切断: \(error?.localizedDescription ?? "正常切断")")
    }
}

extension Notification.Name {
    static let spotifyCallback = Notification.Name("SpotifyCallback")
}
