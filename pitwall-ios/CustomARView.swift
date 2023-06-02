//
//  CustomARView.swift
//  pitwall-ios
//
//  Created by Robin on 2/6/23.
//

import SwiftUI
import Combine
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var camera: Camera
    var car1Pos: CarPositions
    var car2Pos: CarPositions
    
    func makeUIView(context: Context) -> ARView {
        return CustomARView(frame: .zero, camera: camera, car1Pos: car1Pos, car2Pos: car2Pos)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class CustomARView: ARView {
    
    private var sceneUpdateSubscription: AnyCancellable?
    private var car1AnimationSub: AnyCancellable?
    private var car2AnimationSub: AnyCancellable?
    private var car1Pos: CarPositions
    private var car2Pos: CarPositions
            
    required init(frame: CGRect, camera: Camera, car1Pos: CarPositions, car2Pos: CarPositions) {
        self.car1Pos = car1Pos
        self.car2Pos = car2Pos
        super.init(frame: frame)

        super.cameraMode = .nonAR
        super.automaticallyConfigureSession = false
        super.debugOptions = .showWorldOrigin

        let car1Anchor = AnchorEntity(world: [0, 0, 0])
        let car1 = ModelEntity(mesh: .generateSphere(radius: 0.3))
        car1Anchor.addChild(car1)
        super.scene.anchors.append(car1Anchor)
        
        let car2Anchor = AnchorEntity(world: [0, 0, 0])
        let car2 = ModelEntity(mesh: .generateSphere(radius: 0.3))
        car2Anchor.addChild(car2)
        super.scene.anchors.append(car2Anchor)
        
        // Camera follows car1 by default, where car1 is the faster car
        let cameraAnchor = AnchorEntity(world: [camera.x, camera.y, camera.z])
        let perspectiveCamera = PerspectiveCamera()
        cameraAnchor.addChild(perspectiveCamera)
        super.scene.anchors.append(cameraAnchor)
        
        sceneUpdateSubscription = scene.publisher(for: SceneEvents.Update.self, on: nil).sink(receiveValue: { _ in
            perspectiveCamera.move(to: Transform(translation: [camera.x, camera.y, camera.z]), relativeTo: car1)
            perspectiveCamera.look(at: car1.position(relativeTo: nil), from: perspectiveCamera.position(relativeTo: nil), upVector: [0, 1, 0], relativeTo: nil)
        })
        
        car1AnimationSub = scene.publisher(for: AnimationEvents.PlaybackCompleted.self, on: car1).sink(receiveValue: { _ in
            // Check if all movements are already done
            if self.car1Pos.count == self.car1Pos.positions.count {
                self.car1AnimationSub = nil
            } else {
                self.nextMove(model: car1, car: self.car1Pos)
            }
        })
        
        car2AnimationSub = scene.publisher(for: AnimationEvents.PlaybackCompleted.self, on: car2).sink(receiveValue: { _ in
            // Check if all movements are already done
            if self.car2Pos.count == self.car2Pos.positions.count {
                self.car2AnimationSub = nil
            } else {
                self.nextMove(model: car2, car: self.car2Pos)
            }
        })
        
        self.nextMove(model: car1, car: self.car1Pos)
        self.nextMove(model: car2, car: self.car2Pos)
    }
    
    private func nextMove(model: ModelEntity, car: CarPositions) {
        // x and y coords are swapped between F1 live data and RealityKit
        model.move(to: Transform(translation: [car.positions[car.count].x, car.positions[car.count].z, car.positions[car.count].y]), relativeTo: nil, duration: car.positions[car.count].duration, timingFunction: .linear)
        car.count += 1
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }

    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
