
//  MapView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.


import SwiftUI
import MapKit

struct MapView: View {
    @Binding var region: MKCoordinateRegion
    @State private var selectedUser: UserProfile?
    @State private var showingProfile = false
    @State private var selection: Int?
    // Mapで表示した時ユーザーの現在地の場所を表示
    @State private var userCameraPosition: MapCameraPosition = .userLocation(followsHeading: true,fallback: .camera(MapCamera(centerCoordinate: .tokyoStation,distance: 5000,pitch: 0)))
    
    // サンプルユーザーデータ（後で実際のデータに置き換え）
    let sampleUsers: [UserProfile] = [
        UserProfile(
            name: "田中太郎",
            interests: ["カフェ巡り", "写真撮影", "テニス"],
            status: "カフェ巡り中",
            coordinate: CLLocationCoordinate2D(latitude: 35.6702996, longitude: 139.7663888)
        ),
        UserProfile(
            name: "鈴木花子",
            interests: ["読書", "旅行", "料理"],
            status: "新しい友達募集中",
            coordinate: CLLocationCoordinate2D(latitude: 35.6736703, longitude: 139.7638751)
        )
    ]
    
    var body: some View {
        Map(position: $userCameraPosition, selection: $selection){
            ForEach(sampleUsers.map { User(profile: $0) }) { annotation in
                Annotation("", coordinate: annotation.coordinate) {
                    VStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                        Text(annotation.profile.status)
                            .font(.caption)
                            .padding(4)
                            .background(Color.white)
                            .cornerRadius(4)
                            .shadow(radius: 2)
                    }
                    .onTapGesture {
                        selectedUser = annotation.profile
                        showingProfile = true
                    }
                }
            }
            UserAnnotation()
        }
        .sheet(isPresented: $showingProfile) {
            if let user = selectedUser {
                UserProfileSheet(profile: user)
            }
        }
    }
}

// プレビュー用
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(region: .constant(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
}
