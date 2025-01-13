//
//  UserProfileSheet.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import SwiftUI

struct UserProfileSheet: View {
    let profile: UserProfile
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("基本情報")) {
                    Text("名前: \(profile.name)")
                    Text("現在のステータス: \(profile.status)")
                }
                
                Section(header: Text("興味・趣味")) {
                    ForEach(profile.interests, id: \.self) { interest in
                        Text(interest)
                    }
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
