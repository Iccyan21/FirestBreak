//
//  DebugView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/06.
//

import SwiftUI

// デバッグ表示用のView
struct DebugView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            Text("Debug Logs")
                .font(.headline)
                .padding()
            
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(bluetoothManager.debugLogs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
        .background(Color.black.opacity(0.1))
    }
}
