//
//  LocationManager.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//
// アプリ全体で再利用できる、便利で小規模なヘルパー機能をかく

import CoreLocation
import SwiftUI
import Combine
import MapKit

// ユーザーの現在地を取得し、それをリアルタイムでアプリケーション内のUIに反映する
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // ユーザーの位置情報を管理するためのインスタンス
    private let locationManager = CLLocationManager()
    
    // 現在の位置情報を保持するプロパティ
    // このプロパティが更新されると、それを監視しているビューが自動的に再描画
    // CLLocation は位置情報を保持するクラス
    @Published var location: CLLocation?
    
    // マップで表示する領域を定義するプロパティ
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    override init() {
        super.init()
        // このクラス（LocationManager）がCLLocationManagerDelegateのイベントを受け取れるように設定
        locationManager.delegate = self
        // 位置情報の取得精度を最高に設定。
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // 位置情報の使用許可をユーザーにリクエスト
        locationManager.requestWhenInUseAuthorization()
        // 位置情報の取得を開始
        locationManager.startUpdatingLocation()
    }
    // 新しい位置情報を取得したときに呼び出されるデリゲートメソッド
    // locations: 位置情報の配列（最新の位置が最後に追加される）。
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 配列の最後（最新の位置情報）を安全に取得。なければ処理を終了
        guard let location = locations.last else { return }
        // 取得した最新の位置情報をlocationプロパティに保存
        // Publishedで自動更新する
        self.location = location
        //  取得した位置情報を中心としたマップ領域を更新
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}
