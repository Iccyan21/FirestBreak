//
//  FirstBreakApp.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import SwiftUI
import ARKit

//// UIViewControllerRepresentable を使ってUIKitのViewControllerをSwiftUIで使用可能にする
//struct ARSpotifyView: UIViewControllerRepresentable {
//    func makeUIViewController(context: Context) -> ViewController {
//        return ViewController()
//    }
//    
//    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
//        // 更新が必要な場合はここに実装
//    }
//}
//
//// メインのSwiftUIビュー
//struct MainView: View {
//    var body: some View {
//        ARSpotifyView()
//            .edgesIgnoringSafeArea(.all) // ARViewを画面全体に表示
//    }
//}

@main
struct FirstBreakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ARSpotifyView()
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .spotifyCallback,
                        object: url
                    )
                }
                .ignoresSafeArea()
        }
    }
}

//@main
//struct FirstBreakApp: App {
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
//    
//    var body: some Scene {
//        WindowGroup {
//            MainTabView()
//        }
//    }
//}
