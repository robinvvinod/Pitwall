//
//  CustomSceneView.swift
//  pitwall-ios
//
//  Created by Robin on 8/7/23.
//

import Foundation
import SwiftUI
import SceneKit

struct SimulSceneView: UIViewRepresentable {
    
    var scene: SimulScene
    var view = SCNView()
    
    func makeUIView(context: Context) -> SCNView {
        view.scene = scene
        view.delegate = scene
        view.rendersContinuously = true
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        return view
    }
    
    func updateUIView(_ view: SCNView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(view: view, scene: scene)
    }
    
    class Coordinator: NSObject {
        private let view: SCNView
        private let scene: SimulScene
        init(view: SCNView, scene: SimulScene) {
            self.view = view
            self.scene = scene
            super.init()
        }
        
        @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
            // Start movement of cars after user taps screen
            if (scene.car1.position == scene.startPos.p1) && (scene.car2.position == scene.startPos.p2) {
                scene.car1.runAction(scene.car1Seq, forKey: "car1Seq")
                scene.car2.runAction(scene.car2Seq, forKey: "car2Seq")
            }
            
            // Reset car back to start point after tap once action seq is complete
            if (scene.car1.action(forKey: "car1Seq") == nil) && (scene.car2.action(forKey: "car2Seq") == nil) {
                scene.car1.position = scene.startPos.p1
                scene.car2.position = scene.startPos.p2
            }
        }
    }
}
