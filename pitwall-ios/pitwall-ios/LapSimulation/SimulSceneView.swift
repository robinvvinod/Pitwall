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
            var inMotion = false
            for i in 0...(scene.carNodes.count - 1) {
                if scene.carNodes[i].position != scene.startPos[i].p { // check if any cars are already in motion or at end point
                    inMotion = true
                    break
                }
            }
            
            if !inMotion { // If cars are all at start point, start action seq
                var actions = [SCNAction]()
                for i in 0...(scene.carNodes.count - 1) {
                    let action = SCNAction.customAction(duration: 0) { (node, elapsedTime) in
                        self.scene.carNodes[i].runAction(self.scene.carSeq[i])
                    }
                    actions.append(action)
                }
                
                scene.rootNode.runAction(SCNAction.group(actions), forKey: "groupAct")
            } else { // Cars are in motion or at end point
                // Reset car back to start point
                scene.rootNode.removeAllActions()
                for i in 0...(scene.carNodes.count - 1) {
                    scene.carNodes[i].position = scene.startPos[i].p
                }
                
                var actions = [SCNAction]()
                for i in 0...(scene.carNodes.count - 1) {
                    let action = SCNAction.customAction(duration: 0) { (node, elapsedTime) in
                        self.scene.carNodes[i].runAction(self.scene.carSeq[i])
                    }
                    actions.append(action)
                }
                
                scene.rootNode.runAction(SCNAction.group(actions), forKey: "groupAct")
            }
        }
    }
}
