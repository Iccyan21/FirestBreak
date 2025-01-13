
//  MainTabView.swift
//  PlayArchive-iOS
//
//  Created by 水原　樹 on 2024/11/29.


import SwiftUI
import MapKit
import ARKit

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedTab = 0
    @State private var showARView = false
    @StateObject private var profileViewModel = ProfileViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Map View
            MapView(region: $locationManager.region)
                .tabItem {
                    Image("map")
                    Text("Map")
                }
                .tag(0)
            
            // AR View Button
            Button(action: {
                showARView = true
            }) {
                Text("Start AR")
            }
            .sheet(isPresented: $showARView) {
                ARProfileView()
                    .environmentObject(profileViewModel)
            }
            .tabItem {
                Image("person.fill.viewfinder")
                Text("AR")
            }
            .tag(1)
            
            // Profile View
            ProfileView()
                .environmentObject(profileViewModel)
                .tabItem {
                    Image("person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .environmentObject(profileViewModel)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
