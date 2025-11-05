//
//  ContentView.swift
//  PhoropterAR
//
//  Created by 陳慶儒 on 2025/11/5.
//

import SwiftUI
import Combine
import RealityKit
import ARKit

final class HotspotState: ObservableObject {
    @Published var isShowingInfo = false
    @Published var currentPartName: String = ""
    let partInfo: [String: String] = [
        "knob_sphere_power": "球鏡旋鈕：用來調整球面度數（Sphere）。",
        "demo_box": "示範方塊：目前用來替代正式模型。"
    ]
    var currentDescription: String { partInfo[currentPartName] ?? "此部位的說明尚未設定。" }
}

struct ContentView: View {
    @StateObject private var hotspotState = HotspotState()
    var body: some View {
        ZStack {
            ARViewContainer()
                .ignoresSafeArea()
                .environmentObject(hotspotState)
            VStack {
                Text("點一下平面放置模型，點模型看說明")
                    .font(.footnote)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 12)
                Spacer()
            }
        }
        .sheet(isPresented: $hotspotState.isShowingInfo) {
            VStack(spacing: 12) {
                Text(hotspotState.currentPartName).font(.headline)
                Text(hotspotState.currentDescription).multilineTextAlignment(.leading)
                Button("關閉") { hotspotState.isShowingInfo = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .presentationDetents([.fraction(0.3), .medium])
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var hotspotState: HotspotState
    private static var hasPlaced = false

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // 顯示特徵點與錨點原點（黃點/座標軸），看得到就代表追蹤正常
        arView.debugOptions.insert([.showFeaturePoints, .showAnchorOrigins])
        print("AR session started")  // Xcode Console 會印出來

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        context.coordinator.hotspotState = hotspotState
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var arView: ARView?
        weak var hotspotState: HotspotState?

        private func makePlaceholderBox() -> Entity {
            let mesh = MeshResource.generateBox(size: 0.2)
            let mat = SimpleMaterial(color: .gray, isMetallic: false)
            let box = ModelEntity(mesh: mesh, materials: [mat])
            box.name = "knob_sphere_power"
            box.generateCollisionShapes(recursive: true)
            return box
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = sender.location(in: arView)

            if !ARViewContainer.hasPlaced {
                if let hit = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first {
                    let anchor = AnchorEntity(world: hit.worldTransform)
                    anchor.addChild(makePlaceholderBox())
                    arView.scene.addAnchor(anchor)
                } else {
                    let anchor = AnchorEntity(plane: .horizontal)
                    anchor.addChild(makePlaceholderBox())
                    arView.scene.addAnchor(anchor)
                }
                ARViewContainer.hasPlaced = true
                return
            }

            if let entity = arView.entity(at: location) {
                let name = entity.name.isEmpty ? "demo_box" : entity.name
                hotspotState?.currentPartName = name
                hotspotState?.isShowingInfo = true
            } else {
                hotspotState?.isShowingInfo = false
            }
        }
    }
}
