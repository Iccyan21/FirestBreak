//
//  BluetoothManager.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import CoreBluetooth
import MapKit

// CBManagerStateの拡張を追加
extension CBManagerState {
    var stateDescription: String {
        switch self {
        case .unknown:
            return "不明"
        case .resetting:
            return "リセット中"
        case .unsupported:
            return "非対応"
        case .unauthorized:
            return "未認証"
        case .poweredOff:
            return "オフ"
        case .poweredOn:
            return "オン"
        @unknown default:
            return "不明な状態"
        }
    }
}

// プロフィール情報の送受信用の構造体
struct BluetoothProfile: Codable {
    let id: UUID
    let name: String
    let interests: [String]
    let status: String
    
    // UserProfileから変換するイニシャライザ
    init(from profile: UserProfile) {
        self.id = profile.id
        self.name = profile.name
        self.interests = profile.interests
        self.status = profile.status
    }
}


class BluetoothManager: NSObject, ObservableObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate {
    @Published var nearbyUsers: [UserProfile] = []
    @Published var debugLogs: [String] = []
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private let serviceUUID = CBUUID(string: "180D")
    private let characteristicUUID = CBUUID(string: "2A37")
    private var myProfile: UserProfile
    
    // 新しく追加するプロパティ
    @Published var devicePositions: [UUID: DevicePosition] = [:]
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    
    // デバイスの位置情報を管理する構造体
    struct DevicePosition {
        let distance: Double
        let rssi: Int
        let angle: Double  // デバイスの角度（ラジアン）
        let lastUpdate: Date
        
        // 信号強度に基づく信頼度（0.0 - 1.0）
        var reliability: Double {
            // -30dBm以上を1.0、-90dBm以下を0.0として正規化
            let normalizedRSSI = Double(rssi + 90) / 60.0
            return min(max(normalizedRSSI, 0.0), 1.0)
        }
    }
    
    init(myProfile: UserProfile) {
        self.myProfile = myProfile
        super.init()
        addLog("Bluetoothマネージャーを初期化しました")
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    private func startAdvertising() {
        // プロフィール情報をデータに変換
        let bluetoothProfile = BluetoothProfile(from: myProfile)
        guard let profileData = try? JSONEncoder().encode(bluetoothProfile) else {
            addLog("プロフィールデータの変換に失敗しました")
            return
        }
        
        // 特性の設定を修正
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .notify],
            value: nil,  // ここをnilに変更
            permissions: [.readable]
        )
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        
        peripheralManager.add(service)
        
        // データを後から設定
        peripheralManager.updateValue(
            profileData,
            for: characteristic,
            onSubscribedCentrals: nil
        )
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "AR Profile"
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        addLog("プロフィール情報の共有を開始しました")
    }
    
    // デバイス検出時の処理を更新
    // BluetoothManagerのdidDiscoverメソッドを修正
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        addLog("デバイスを検出: \(peripheral.name ?? "不明") - 信号強度: \(RSSI)")
        
        let testProfile = UserProfile(
            id: peripheral.identifier,  // 重要: 同じIDを使用
            name: peripheral.name ?? "不明なユーザー",
            interests: ["AR", "スマートフォン", "技術"],
            status: "オンライン",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        
        // デバイス位置情報を確実に更新
        let position = DevicePosition(
            distance: calculateDistance(RSSI: RSSI.intValue),
            rssi: RSSI.intValue,
            angle: Double.random(in: 0...(2 * .pi)),
            lastUpdate: Date()
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 位置情報を先に更新
            self.devicePositions[peripheral.identifier] = position
            self.addLog("位置情報を更新: 距離 \(position.distance)m")
            
            // ユーザー情報を更新
            if !self.nearbyUsers.contains(where: { $0.id == testProfile.id }) {
                self.nearbyUsers.append(testProfile)
                self.addLog("新規ユーザー追加: \(testProfile.name)")
            }
            
            // 既存のユーザー情報を更新
            if let index = self.nearbyUsers.firstIndex(where: { $0.id == testProfile.id }) {
                self.nearbyUsers[index] = testProfile
            }
        }
    }
    
    // デバイスの位置情報を更新する関数
    private func updateDevicePosition(for peripheral: CBPeripheral, rssi: NSNumber) {
        let distance = calculateDistance(RSSI: rssi.intValue)
        let angle = calculateDeviceAngle(for: peripheral)
        
        let position = DevicePosition(
            distance: distance,
            rssi: rssi.intValue,
            angle: angle,
            lastUpdate: Date()
        )
        
        DispatchQueue.main.async {
            self.devicePositions[peripheral.identifier] = position
            self.addLog("デバイス位置を更新: \(peripheral.name ?? "不明") - 距離: \(String(format: "%.2f", distance))m")
        }
    }
    
    // デバイスの角度を計算する関数
    private func calculateDeviceAngle(for peripheral: CBPeripheral) -> Double {
        // 現在のデバイスの向きを取得
        if let existingPosition = devicePositions[peripheral.identifier] {
            // 既存の角度から少しだけランダムに変動させる（より自然な動きのため）
            let variation = Double.random(in: -0.1...0.1)
            return existingPosition.angle + variation
        } else {
            // 新規デバイスの場合はランダムな角度を割り当て
            return Double.random(in: 0...(2 * .pi))
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        print(logMessage)  // コンソールにも出力
        DispatchQueue.main.async {
            self.debugLogs.append(logMessage)
            // 最新100件のみ保持
            if self.debugLogs.count > 100 {
                self.debugLogs.removeFirst()
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        addLog("セントラルマネージャーの状態が更新されました: \(central.state.stateDescription)")
        if central.state == .poweredOn {
            addLog("周辺デバイスのスキャンを開始します")
            centralManager.scanForPeripherals(withServices: [serviceUUID])
        }
    }
    
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        addLog("ペリフェラルマネージャーの状態が更新されました: \(peripheral.state.stateDescription)")
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            addLog("デバイス検出の開始に失敗しました: \(error.localizedDescription)")
        } else {
            addLog("デバイス検出を正常に開始しました")
        }
    }
    
    // RSSI値から距離を概算する関数
    private func calculateDistance(RSSI: Int) -> Double {
        // 理想的な環境での簡易的な距離計算
        // RSSI = -20 * log10(distance) - 41
        // distance = 10 ^ ((RSSI + 41) / -20)
        let distance = pow(10.0, Double(RSSI + 41) / -20.0)
        return distance
    }
    
    // 古いデバイス位置情報をクリーンアップする関数
    private func cleanupOldDevices() {
        let threshold = Date().addingTimeInterval(-30)  // 30秒以上更新がないデバイスを削除
        
        devicePositions = devicePositions.filter { $0.value.lastUpdate > threshold }
    }
    
    // 定期的なクリーンアップを開始する関数
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.cleanupOldDevices()
        }
    }
    
}
    
 
// CBPeripheralDelegate プロトコルを追加
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics where characteristic.uuid == characteristicUUID {
            peripheral.readValue(for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let receivedProfile = try? JSONDecoder().decode(BluetoothProfile.self, from: data) else {
            addLog("プロフィールデータの読み取りに失敗しました")
            return
        }
        
        // 受信したプロフィール情報をUserProfileに変換
        let userProfile = UserProfile(
            id: receivedProfile.id,
            name: receivedProfile.name,
            interests: receivedProfile.interests,
            status: receivedProfile.status,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        
        DispatchQueue.main.async {
            // 重複を避けてプロフィールを追加
            if !self.nearbyUsers.contains(where: { $0.id == userProfile.id }) {
                self.nearbyUsers.append(userProfile)
                self.addLog("新しいユーザーのプロフィールを受信: \(userProfile.name)")
            }
        }
    }
}

// BluetoothManagerに追加
extension BluetoothManager {
    func updateMyProfile(_ newProfile: UserProfile) {
        myProfile = newProfile
        // 必要に応じて広告データを更新
        if peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
            startAdvertising()
        }
    }
}
