//
//  ARFaceView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2024/12/13.
//
//import SwiftUI
//import ARKit
//import RealityKit
//
//struct ARFaceView: View {
//    @State private var isARViewPresented = false
//    
//    var body: some View {
//        VStack {
//            Text("AR World Tracking Demo")
//                .font(.title)
//                .padding()
//            
//            Button(action: {
//                isARViewPresented = true
//            }) {
//                Text("Start AR")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(10)
//            }
//        }
//        .fullScreenCover(isPresented: $isARViewPresented) {
//            ARViewWithDismiss(isPresented: $isARViewPresented)
//        }
//    }
//}
//
//struct ARViewWithDismiss: View {
//    @Binding var isPresented: Bool
//    
//    var body: some View {
//        ZStack {
//            ARViewContainer()
//                .edgesIgnoringSafeArea(.all)
//            
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: {
//                        isPresented = false
//                    }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title)
//                            .foregroundColor(.white)
//                            .padding()
//                    }
//                }
//                Spacer()
//            }
//        }
//    }
//}
//
//class WorldARViewCoordinator: NSObject, ARSessionDelegate {
//    weak var arView: ARView?
//    var textEntity: ModelEntity?
//    
//    init(arView: ARView) {
//        self.arView = arView
//        super.init()
//    }
//    
//    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        guard let arView = arView else { return }
//        
//        // 3Dテキストを作成
//        let textMesh = MeshResource.generateText(
//            "Hello World!",
//            extrusionDepth: 0.01,
//            font: .systemFont(ofSize: 0.1),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byTruncatingTail
//        )
//        
//        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
//        let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
//        
//        // テキストを空中に配置
//        textModel.position = SIMD3(x: 0, y: 0.2, z: -0.5)
//        
//        // テキストをシーンに追加
//        let anchorEntity = AnchorEntity(world: .zero)
//        anchorEntity.addChild(textModel)
//        arView.scene.addAnchor(anchorEntity)
//        
//        self.textEntity = textModel
//    }
//    
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        print("AR Session Failed: \(error)")
//    }
//    
//    func sessionWasInterrupted(_ session: ARSession) {
//        print("AR Session Interrupted")
//    }
//    
//    func sessionInterruptionEnded(_ session: ARSession) {
//        print("AR Session Interruption Ended")
//        resetTracking()
//    }
//    
//    func resetTracking() {
//        guard let arView = arView else { return }
//        
//        // Reset and restart AR session with new configuration
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.horizontal]
//        
//        arView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
//    }
//}
//
//struct ARViewContainer: UIViewRepresentable {
//    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
//        
//        // World tracking configuration
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.horizontal]
//        configuration.isLightEstimationEnabled = true
//        
//        let coordinator = context.coordinator
//        coordinator.arView = arView
//        arView.session.delegate = coordinator
//        
//        // Start AR session
//        arView.session.run(configuration)
//        
//        return arView
//    }
//    
//    func updateUIView(_ uiView: ARView, context: Context) {}
//    
//    func makeCoordinator() -> WorldARViewCoordinator {
//        WorldARViewCoordinator(arView: ARView(frame: .zero))
//    }
//}
//#Preview {
//    ARFaceView()
//}
