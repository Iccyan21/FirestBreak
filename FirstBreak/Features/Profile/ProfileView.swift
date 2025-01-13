////
////  ProfileView.swift
////  PlayArchive-iOS
////
////  Created by 水原　樹 on 2024/11/29.
////
//
import SwiftUI
import MapKit


struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var newInterest = ""
    @State private var isEditMode = false
    
    // 選択可能なステータスのリスト
    let statusOptions = [
        "オンライン",
        "カフェ巡り中",
        "新しい友達募集中",
        "仕事中",
        "観光中",
        "食事中"
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("基本情報")) {
                    if isEditMode {
                        TextField("名前", text: $viewModel.profile.name)
                        Picker("ステータス", selection: $viewModel.profile.status) {
                            ForEach(statusOptions, id: \.self) { status in
                                Text(status).tag(status)
                            }
                        }
                    } else {
                        HStack {
                            Text("名前")
                            Spacer()
                            Text(viewModel.profile.name)
                        }
                        HStack {
                            Text("ステータス")
                            Spacer()
                            Text(viewModel.profile.status)
                        }
                    }
                }
                
                Section(header: Text("興味・趣味")) {
                    if isEditMode {
                        HStack {
                            TextField("新しい趣味を追加", text: $newInterest)
                            Button(action: {
                                if !newInterest.isEmpty {
                                    viewModel.profile.interests.append(newInterest)
                                    newInterest = ""
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                    
                    ForEach(viewModel.profile.interests, id: \.self) { interest in
                        Text(interest)
                    }
                    .onDelete(perform: isEditMode ? deleteInterest : nil)
                }
                
                Section(header: Text("プライバシー設定")) {
                    Toggle("位置情報を共有", isOn: .constant(true))
                    Toggle("プロフィールを公開", isOn: .constant(true))
                }
            }
            .navigationTitle("マイプロフィール")
            .navigationBarItems(trailing: Button(isEditMode ? "完了" : "編集") {
                if isEditMode {
                    viewModel.saveProfile()
                }
                isEditMode.toggle()
            })
            .animation(.default, value: isEditMode)
        }
    }
    
    private func deleteInterest(at offsets: IndexSet) {
        viewModel.profile.interests.remove(atOffsets: offsets)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
