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
            self?.updateARDisplayFromBluetoothAppleStyle(with: playbackInfo)
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
    // updateARDisplay メソッドを Apple風デザイン版に置き換え
    private func updateARDisplayAppleStyle(with playerState: SPTAppRemotePlayerState) {
        updateARDisplayWithImprovedLayout(with: playerState)
        sharePlaybackInfo(from: playerState)
    }
        
        // updateARDisplayFromBluetooth メソッドを Apple風デザイン版に置き換え
    private func updateARDisplayFromBluetoothAppleStyle(with playbackInfo: SpotifyPlaybackInfo) {
        updateARDisplayFromBluetoothWithImprovedLayout(with: playbackInfo)
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
                    self?.updateARDisplayAppleStyle(with: state)
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
                            self?.updateARDisplayAppleStyle(with: state)
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
}// 🎯 改善されたApple風ARレイアウト

import UIKit
import ARKit
import SceneKit
import SpotifyiOS

extension ViewController {
    
    // MARK: - 改善されたApple風デザイン（レイアウト修正版）
    private func updateARDisplayWithImprovedLayout(with playerState: SPTAppRemotePlayerState) {
        print("🎨 改善されたAR表示更新開始（自分の曲）")
        currentTrackNode?.removeFromParentNode()
        
        guard let camera = sceneView.pointOfView else { return }
        
        // メインコンテナノード
        let containerNode = SCNNode()
        
        // 1. 美しいカード背景（統一されたサイズ）
        let cardNode = createUnifiedCard(isOtherUser: false)
        
        // 2. 垂直レイアウトコンテナ
        let contentContainer = SCNNode()
        
        // 3. アートワーク用プレースホルダー（上部）
        let artworkPlaceholder = createArtworkPlaceholder()
        artworkPlaceholder.position = SCNVector3(0, 0.08, 0.002) // カードの上部
        
        // 4. テキスト情報（下部）
        let textContainer = createTextContainer(
            title: playerState.track.name,
            artist: playerState.track.artist.name,
            isOtherUser: false,
            isPlaying: true
        )
        textContainer.position = SCNVector3(0, -0.05, 0.002) // カードの下部
        
        // レイアウト組み立て
        contentContainer.addChildNode(artworkPlaceholder)
        contentContainer.addChildNode(textContainer)
        
        containerNode.addChildNode(cardNode)
        containerNode.addChildNode(contentContainer)
        
        // カメラからの相対位置（左側）
        let position = SCNVector3(-0.4, 0.1, -0.8)
        containerNode.position = camera.convertPosition(position, to: nil)
        
        // 改善されたアニメーション
        addImprovedAnimation(to: containerNode)
        
        sceneView.scene.rootNode.addChildNode(containerNode)
        currentTrackNode = containerNode
        
        // アートワーク取得とレイアウト適用
        fetchAndDisplayImprovedArtwork(
            for: playerState,
            placeholder: artworkPlaceholder,
            camera: camera
        )
    }
    
    // MARK: - 相手用の改善されたレイアウト
    private func updateARDisplayFromBluetoothWithImprovedLayout(with playbackInfo: SpotifyPlaybackInfo) {
        print("🎨 改善されたAR表示更新開始（相手の曲）")
        otherTrackNode?.removeFromParentNode()
        
        guard let camera = sceneView.pointOfView else { return }
        
        let containerNode = SCNNode()
        
        // 相手用カード
        let cardNode = createUnifiedCard(isOtherUser: true)
        
        let contentContainer = SCNNode()
        
        // アートワーク用プレースホルダー
        let artworkPlaceholder = createArtworkPlaceholder()
        artworkPlaceholder.position = SCNVector3(0, 0.08, 0.002)
        
        // テキスト情報
        let textContainer = createTextContainer(
            title: playbackInfo.trackName,
            artist: playbackInfo.artistName,
            isOtherUser: true,
            isPlaying: true
        )
        textContainer.position = SCNVector3(0, -0.05, 0.002)
        
        contentContainer.addChildNode(artworkPlaceholder)
        contentContainer.addChildNode(textContainer)
        
        containerNode.addChildNode(cardNode)
        containerNode.addChildNode(contentContainer)
        
        // 右側に配置
        let position = SCNVector3(0.4, 0.1, -0.8)
        containerNode.position = camera.convertPosition(position, to: nil)
        
        addImprovedAnimation(to: containerNode)
        
        sceneView.scene.rootNode.addChildNode(containerNode)
        otherTrackNode = containerNode
        
        // ネットワーク経由でアートワーク取得
        fetchNetworkArtworkImproved(
            url: playbackInfo.albumArtURL,
            placeholder: artworkPlaceholder,
            camera: camera
        )
    }
    
    // MARK: - 統一されたカードデザイン
    private func createUnifiedCard(isOtherUser: Bool = false) -> SCNNode {
        // Apple Musicライクなカードサイズ（縦長の黄金比）
        let cardWidth: CGFloat = 0.35
        let cardHeight: CGFloat = 0.4
        
        let cardGeometry = SCNPlane(width: cardWidth, height: cardHeight)
        
        // マテリアル設定
        let material = SCNMaterial()
        
        if isOtherUser {
            // 相手用：青系のグラデーション
            material.diffuse.contents = createGradientImage(
                colors: [UIColor.systemBlue.withAlphaComponent(0.95), UIColor.systemTeal.withAlphaComponent(0.8)],
                size: CGSize(width: 100, height: 100)
            )
        } else {
            // 自分用：暖色系のグラデーション
            material.diffuse.contents = createGradientImage(
                colors: [UIColor.systemBackground.withAlphaComponent(0.95), UIColor.systemGray6.withAlphaComponent(0.8)],
                size: CGSize(width: 100, height: 100)
            )
        }
        
        // Apple風のマテリアル設定
        material.metalness.contents = 0.05
        material.roughness.contents = 0.1
        material.isDoubleSided = true
        
        // 影とボーダー効果
        material.multiply.contents = UIColor.black.withAlphaComponent(0.03)
        
        cardGeometry.materials = [material]
        cardGeometry.cornerRadius = 0.025 // Apple風の角丸
        
        return SCNNode(geometry: cardGeometry)
    }
    
    // MARK: - アートワーク用プレースホルダー
    private func createArtworkPlaceholder() -> SCNNode {
        let placeholderSize: CGFloat = 0.15
        let placeholderGeometry = SCNPlane(width: placeholderSize, height: placeholderSize)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemGray5.withAlphaComponent(0.3)
        material.isDoubleSided = true
        
        placeholderGeometry.materials = [material]
        placeholderGeometry.cornerRadius = 0.015
        
        return SCNNode(geometry: placeholderGeometry)
    }
    
    //
    private func createTextContainer(title: String, artist: String, isOtherUser: Bool) -> SCNNode {
        let textContainer = SCNNode()
        
        // タイトル（強制左寄り）
        let titleNode = createForceLeftAlignedText(
            text: title,
            fontSize: 14,
            weight: .semibold,
            color: isOtherUser ? UIColor.systemBlue : UIColor.white
        )
        titleNode.position.y = 0.3  // Y座標のみ変更

        // アーティスト名（強制左寄り）
        let artistNode = createForceLeftAlignedText(
            text: artist,
            fontSize: 12,
            weight: .regular,
            color: isOtherUser ? UIColor.systemBlue.withAlphaComponent(0.7) : UIColor.secondaryLabel
        )
        artistNode.position.y = -0.050  // Y座標のみ変更

        textContainer.addChildNode(titleNode)
        textContainer.addChildNode(artistNode)
        
        return textContainer
    }
    
    // MARK: - 強制左寄りテキスト（新メソッド）
        private func createForceLeftAlignedText(text: String, fontSize: CGFloat, weight: UIFont.Weight,
                                              color: UIColor) -> SCNNode {
            print("🚀 強制左寄りテキスト作成開始: \(text)")
            
            let truncatedText = truncateText(text, maxLength: 25)
            
            let textGeometry = SCNText(string: truncatedText, extrusionDepth: 0.001)
            textGeometry.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
            textGeometry.firstMaterial?.diffuse.contents = color
            textGeometry.firstMaterial?.isDoubleSided = true
            textGeometry.firstMaterial?.metalness.contents = 0.0
            textGeometry.firstMaterial?.roughness.contents = 1.0
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.scale = SCNVector3(0.0025, 0.0025, 0.0025)
            
                        // 🎯 絶対に左寄りにする！
            textNode.position.x = -0.08  // 異次元レベルの左寄り！
            
            print("✅ 強制左寄り完了: x = \(textNode.position.x)")
            
            return textNode
        }
        
        // MARK: - 新しいテキストコンテナ（強制左寄り版）
    private func createForceLeftTextContainer(title: String, artist: String, isOtherUser: Bool) -> SCNNode {
        let textContainer = SCNNode()
        
        // タイトル（強制左寄り）
        let titleNode = createForceLeftAlignedText(
            text: title,
            fontSize: 14,
            weight: .semibold,
            color: isOtherUser ? UIColor.systemBlue : UIColor.white
        )
        titleNode.position = SCNVector3(0, 0.018, 0)
        
        // アーティスト名（強制左寄り）
        let artistNode = createForceLeftAlignedText(
            text: artist,
            fontSize: 12,
            weight: .regular,
            color: isOtherUser ? UIColor.systemBlue : UIColor.white  // 🎯 自分の場合は少し透明な白色
        )
        artistNode.position = SCNVector3(0, -0.018, 0)
        
        textContainer.addChildNode(titleNode)
        textContainer.addChildNode(artistNode)
        
        return textContainer
    }
    
    // MARK: - 改善されたアートワーク表示
    private func createImprovedAlbumArtwork(with image: UIImage) -> SCNNode {
        let artworkSize: CGFloat = 0.15
        let plane = SCNPlane(width: artworkSize, height: artworkSize)
        
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.isDoubleSided = true
        
        // 高品質表示設定
        material.metalness.contents = 0.0
        material.roughness.contents = 0.2
        
        plane.materials = [material]
        plane.cornerRadius = 0.015 // 角丸
        
        let artworkNode = SCNNode(geometry: plane)
        
        // 軽微な影効果
        addSubtleShadow(to: artworkNode)
        
        return artworkNode
    }
    
    // MARK: - 改善されたアニメーション
    private func addImprovedAnimation(to node: SCNNode) {
        // 1. 登場アニメーション
        node.opacity = 0.0
        node.scale = SCNVector3(0.3, 0.3, 0.3)
        
        let fadeIn = SCNAction.fadeIn(duration: 0.6)
        let scaleUp = SCNAction.scale(to: 1.0, duration: 0.8)
        
        fadeIn.timingMode = SCNActionTimingMode.easeOut
        scaleUp.timingMode = SCNActionTimingMode.easeOut
        
        let appearGroup = SCNAction.group([fadeIn, scaleUp])
        node.runAction(appearGroup)
        
        // 2. 継続的な微細アニメーション
        addSubtleIdleAnimation(to: node)
    }
    
    // MARK: - 微細なアイドルアニメーション
    private func addSubtleIdleAnimation(to node: SCNNode) {
        // 非常に軽微な浮遊
        let floatUp = SCNAction.moveBy(x: 0, y: 0.003, z: 0, duration: 3.0)
        let floatDown = SCNAction.moveBy(x: 0, y: -0.003, z: 0, duration: 3.0)
        
        floatUp.timingMode = SCNActionTimingMode.easeInEaseOut
        floatDown.timingMode = SCNActionTimingMode.easeInEaseOut
        
        let floatSequence = SCNAction.sequence([floatUp, floatDown])
        let floatForever = SCNAction.repeatForever(floatSequence)
        
        node.runAction(floatForever, forKey: "subtleFloat")
    }
    
    // MARK: - アートワーク取得（改善版）
    private func fetchAndDisplayImprovedArtwork(for playerState: SPTAppRemotePlayerState,
                                              placeholder: SCNNode, camera: SCNNode) {
        appRemote?.imageAPI?.fetchImage(forItem: playerState.track,
                                      with: CGSize(width: 400, height: 400)) { [weak self] (result, error) in
            if let image = result as? UIImage {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // プレースホルダーを置き換え
                    let artworkNode = self.createImprovedAlbumArtwork(with: image)
                    artworkNode.position = placeholder.position
                    
                    // スムーズな切り替えアニメーション
                    artworkNode.opacity = 0.0
                    
                    if let parent = placeholder.parent {
                        parent.addChildNode(artworkNode)
                        
                        let fadeOut = SCNAction.fadeOut(duration: 0.2)
                        let fadeIn = SCNAction.fadeIn(duration: 0.3)
                        
                        placeholder.runAction(fadeOut) {
                            placeholder.removeFromParentNode()
                        }
                        
                        artworkNode.runAction(fadeIn)
                    }
                    
                    print("✨ 改善されたアートワーク表示完了")
                }
            }
        }
    }
    
    // MARK: - ネットワークアートワーク取得（改善版）
    private func fetchNetworkArtworkImproved(url: String, placeholder: SCNNode, camera: SCNNode) {
        guard let imageURL = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: imageURL) { [weak self] (data, response, error) in
            guard let self = self,
                  let imageData = data,
                  let image = UIImage(data: imageData) else {
                print("🖼️ ネットワーク画像取得失敗")
                return
            }
            
            DispatchQueue.main.async {
                let artworkNode = self.createImprovedAlbumArtwork(with: image)
                artworkNode.position = placeholder.position
                
                artworkNode.opacity = 0.0
                
                if let parent = placeholder.parent {
                    parent.addChildNode(artworkNode)
                    
                    let fadeOut = SCNAction.fadeOut(duration: 0.2)
                    let fadeIn = SCNAction.fadeIn(duration: 0.3)
                    
                    placeholder.runAction(fadeOut) {
                        placeholder.removeFromParentNode()
                    }
                    
                    artworkNode.runAction(fadeIn)
                }
                
                print("✨ ネットワーク経由改善アートワーク表示完了")
            }
        }.resume()
    }
    
    // MARK: - ヘルパー関数
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxLength - 3)
        return String(text[..<index]) + "..."
    }
    
    private func createGradientImage(colors: [UIColor], size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors.map { $0.cgColor } as CFArray,
                                    locations: nil)!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: 0, y: size.height),
                                               options: [])
        }
    }
    
    private func addSubtleShadow(to node: SCNNode) {
        // 軽微な影ノード
        let shadowPlane = SCNPlane(width: 0.16, height: 0.16)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.15)
        shadowMaterial.isDoubleSided = false
        shadowPlane.materials = [shadowMaterial]
        
        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.position = SCNVector3(0.003, -0.003, -0.001)
        
        node.addChildNode(shadowNode)
    }
}

// 🎵 再生中のデザインエフェクト

extension ViewController {
    
    // MARK: - 再生中インジケーター付きコンテナ
    private func createPlayingContainer(title: String, artist: String, isOtherUser: Bool, isPlaying: Bool = true) -> SCNNode {
        let textContainer = SCNNode()
        
        let titleNode = createForceLeftAlignedText(
            text: title,
            fontSize: 14,
            weight: .semibold,
            color: isOtherUser ? UIColor.black : UIColor.white
        )
        titleNode.position.y = 0.01
        
        let artistNode = createForceLeftAlignedText(
            text: artist,
            fontSize: 12,
            weight: .regular,
            color: isOtherUser ? UIColor.black.withAlphaComponent(0.7) : UIColor.white.withAlphaComponent(0.8)
        )
        artistNode.position.y = -0.025
        
        textContainer.addChildNode(titleNode)
        textContainer.addChildNode(artistNode)
        
        // 🎵 再生中の場合、インジケーターを追加
        if isPlaying {
            let playingIndicator = createPlayingIndicator(isOtherUser: isOtherUser)
            playingIndicator.position = SCNVector3(-0.08, -0.06, 0.001) // テキストの右側
            textContainer.addChildNode(playingIndicator)
        }
        
        return textContainer
    }
    
    // MARK: - 再生中インジケーター（音波アニメーション）
    private func createPlayingIndicator(isOtherUser: Bool) -> SCNNode {
        let container = SCNNode()
        
        // 3本の音波バー
        for i in 0..<3 {
            let barHeight: Float = 0.015 + Float(i) * 0.005 // 異なる高さ
            let bar = createSoundBar(height: barHeight, isOtherUser: isOtherUser)
            
            bar.position.x = Float(i) * 0.008 // 横に並べる
            container.addChildNode(bar)
            
            // 各バーに異なるアニメーション
            addSoundWaveAnimation(to: bar, delay: Double(i) * 0.2)
        }
        
        return container
    }
    
    // MARK: - 音波バーの作成
    private func createSoundBar(height: Float, isOtherUser: Bool) -> SCNNode {
        let barGeometry = SCNBox(width: 0.004, height: CGFloat(height), length: 0.002, chamferRadius: 0.001)
        
        let material = SCNMaterial()
        material.diffuse.contents = isOtherUser ? UIColor.systemBlue : UIColor.white
        material.emission.contents = isOtherUser ? UIColor.systemBlue.withAlphaComponent(0.3) : UIColor.white.withAlphaComponent(0.3)
        
        barGeometry.materials = [material]
        return SCNNode(geometry: barGeometry)
    }
    
    // MARK: - 音波アニメーション
    private func addSoundWaveAnimation(to bar: SCNNode, delay: Double) {
        // ランダムな高さ変動（型を修正）
        let scaleUp = SCNAction.scale(to: 1.8, duration: 0.3)
        let scaleDown = SCNAction.scale(to: 0.6, duration: 0.4)
        let scaleNormal = SCNAction.scale(to: 1.0, duration: 0.3)
        
        scaleUp.timingMode = SCNActionTimingMode.easeInEaseOut
        scaleDown.timingMode = SCNActionTimingMode.easeInEaseOut
        scaleNormal.timingMode = SCNActionTimingMode.easeInEaseOut
        
        let sequence = SCNAction.sequence([scaleUp, scaleDown, scaleNormal])
        let repeatForever = SCNAction.repeatForever(sequence)
        
        // 遅延を追加して自然な音波効果
        let delayAction = SCNAction.wait(duration: delay)
        let finalAction = SCNAction.sequence([delayAction, repeatForever])
        
        bar.runAction(finalAction, forKey: "soundWave")
    }
    
    // MARK: - プログレスバー（再生進行状況）
    private func createProgressBar(progress: Float, isOtherUser: Bool) -> SCNNode {
        let container = SCNNode()
        
        // 背景バー
        let backgroundBar = SCNBox(width: 0.2, height: 0.003, length: 0.001, chamferRadius: 0.0015)
        let backgroundMaterial = SCNMaterial()
        backgroundMaterial.diffuse.contents = UIColor.gray.withAlphaComponent(0.3)
        backgroundBar.materials = [backgroundMaterial]
        
        let backgroundNode = SCNNode(geometry: backgroundBar)
        container.addChildNode(backgroundNode)
        
        // プログレスバー
        let progressWidth = 0.2 * Double(progress) // 進行状況に応じた幅
        let progressBar = SCNBox(width: progressWidth, height: 0.004, length: 0.002, chamferRadius: 0.002)
        let progressMaterial = SCNMaterial()
        progressMaterial.diffuse.contents = isOtherUser ? UIColor.systemBlue : UIColor.white
        progressMaterial.emission.contents = isOtherUser ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.white.withAlphaComponent(0.2)
        progressBar.materials = [progressMaterial]
        
        let progressNode = SCNNode(geometry: progressBar)
        // 左寄せで配置
        progressNode.position.x = Float(-0.1 + progressWidth/2)
        container.addChildNode(progressNode)
        
        return container
    }
    
    // MARK: - パルス効果（心拍のような）
    private func addPulseEffect(to node: SCNNode) {
        let pulseUp = SCNAction.scale(to: 1.05, duration: 0.8)
        let pulseDown = SCNAction.scale(to: 1.0, duration: 0.8)
        
        pulseUp.timingMode = SCNActionTimingMode.easeInEaseOut
        pulseDown.timingMode = SCNActionTimingMode.easeInEaseOut
        
        let pulseSequence = SCNAction.sequence([pulseUp, pulseDown])
        let repeatPulse = SCNAction.repeatForever(pulseSequence)
        
        node.runAction(repeatPulse, forKey: "pulse")
    }
    
    // MARK: - 改善されたテキストコンテナ（再生状態対応）
    private func createTextContainer(title: String, artist: String, isOtherUser: Bool, isPlaying: Bool = true) -> SCNNode {
        return createPlayingContainer(title: title, artist: artist, isOtherUser: isOtherUser, isPlaying: isPlaying)
    }
    
    // MARK: - アートワークに再生エフェクトを追加
    private func addPlayingEffectToArtwork(_ artworkNode: SCNNode, isPlaying: Bool) {
        if isPlaying {
            // 1. 軽微な回転アニメーション
            let rotation = SCNAction.rotateBy(x: 0, y: 0.1, z: 0, duration: 8.0)
            let rotateForever = SCNAction.repeatForever(rotation)
            artworkNode.runAction(rotateForever, forKey: "playing_rotation")
            
            // 2. 発光エフェクト
            if let geometry = artworkNode.geometry as? SCNPlane,
               let material = geometry.materials.first {
                material.emission.contents = UIColor.white.withAlphaComponent(0.1)
                
                // 発光のパルス
                let brighten = SCNAction.customAction(duration: 1.0) { (node, elapsedTime) in
                    let intensity = 0.1 + 0.05 * sin(Float(elapsedTime) * 2 * Float.pi)
                    material.emission.contents = UIColor.white.withAlphaComponent(CGFloat(intensity))
                }
                let repeatBrighten = SCNAction.repeatForever(brighten)
                artworkNode.runAction(repeatBrighten, forKey: "playing_glow")
            }
        } else {
            // 再生停止時はエフェクトを停止
            artworkNode.removeAction(forKey: "playing_rotation")
            artworkNode.removeAction(forKey: "playing_glow")
        }
    }
    
    // MARK: - 使用例：完全な再生中カード
    private func createPlayingMusicCard(title: String, artist: String, artworkImage: UIImage?,
                                      isOtherUser: Bool, isPlaying: Bool, progress: Float = 0.0) -> SCNNode {
        let containerNode = SCNNode()
        
        // 1. カード背景
        let cardNode = createUnifiedCard(isOtherUser: isOtherUser)
        
        // 2. アートワーク（再生エフェクト付き）
        if let image = artworkImage {
            let artworkNode = createImprovedAlbumArtwork(with: image)
            artworkNode.position = SCNVector3(0, 0.08, 0.002)
            addPlayingEffectToArtwork(artworkNode, isPlaying: isPlaying)
            containerNode.addChildNode(artworkNode)
        }
        
        // 3. テキスト（再生インジケーター付き）
        let textContainer = createPlayingContainer(title: title, artist: artist,
                                                 isOtherUser: isOtherUser, isPlaying: isPlaying)
        textContainer.position = SCNVector3(0, -0.05, 0.002)
        
        // 4. プログレスバー
        if isPlaying && progress > 0 {
            let progressBar = createProgressBar(progress: progress, isOtherUser: isOtherUser)
            progressBar.position = SCNVector3(0, -0.12, 0.002)
            containerNode.addChildNode(progressBar)
        }
        
        containerNode.addChildNode(cardNode)
        containerNode.addChildNode(textContainer)
        
        // 5. 再生中は全体にパルス効果
        if isPlaying {
            addPulseEffect(to: containerNode)
        }
        
        return containerNode
    }
}
