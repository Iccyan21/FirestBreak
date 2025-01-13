//
//  ARViewContainer.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2025/01/04.
//

//import SwiftUI
//import ARKit
//import RealityKit
//
//struct ARViewContainer: UIViewRepresentable {
//    @ObservedObject var arViewModel: ARViewModel
//    
//    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero)
//        let config = ARWorldTrackingConfiguration()
//        arView.session.run(config)
//        return arView
//    }
//    
//    func updateUIView(_ uiView: ARView, context: Context) {
//        if let trackInfo = arViewModel.currentTrackInfo {
//            updateTrackAnchor(in: uiView, with: trackInfo)
//        }
//    }
//    
//    private func updateTrackAnchor(in arView: ARView, with trackInfo: TrackInfo) {
//        // Remove existing anchors
//        arView.scene.anchors.removeAll()
//        
//        // Create text entity
//        let textMesh = MeshResource.generateText(
//            trackInfo.title,
//            extrusionDepth: 0.01,
//            font: .systemFont(ofSize: 0.1),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byTruncatingTail
//        )
//        
//        let textMaterial = SimpleMaterial(color: .white, isMetallic: true)
//        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
//        
//        // Create anchor and add to scene
//        let anchor = AnchorEntity(plane: .horizontal)
//        anchor.addChild(textEntity)
//        arView.scene.addAnchor(anchor)
//    }
//}
