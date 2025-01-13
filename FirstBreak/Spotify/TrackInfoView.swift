//
//  TrackInfoView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2025/01/04.
//

//import Foundation
//import SwiftUI
//
//struct TrackInfoView: View {
//    let track: Track
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            AsyncImage(url: URL(string: track.album.images.first?.url ?? "")) { image in
//                image
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 200, height: 200)
//                    .cornerRadius(8)
//            } placeholder: {
//                ProgressView()
//            }
//            
//            Text(track.name)
//                .font(.title2)
//                .bold()
//            
//            Text(track.artists.map(\.name).joined(separator: ", "))
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//        .padding()
//        .background(.ultraThinMaterial)
//        .cornerRadius(16)
//        .padding()
//    }
//}
