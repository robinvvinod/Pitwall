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

        self.cameraMode = .nonAR
        self.automaticallyConfigureSession = false
        self.debugOptions = .showWorldOrigin
        self.renderOptions = [.disableMotionBlur,
                              .disableDepthOfField,
                              .disablePersonOcclusion,
                              .disableGroundingShadows,
                              .disableFaceMesh,
                              .disableHDR]

        let car1Anchor = AnchorEntity(world: [0, 0, 0])
        let car1 = ModelEntity(mesh: .generateBox(size: 0.03))
        car1Anchor.addChild(car1)
        self.scene.addAnchor(car1Anchor)
        
        let car2Anchor = AnchorEntity(world: [0, 0, 0])
        let car2 = ModelEntity(mesh: .generateBox(size: 0.03))
        car2Anchor.addChild(car2)
        self.scene.addAnchor(car2Anchor)
        
        // Camera follows car1 by default, where car1 is the faster car
        let cameraAnchor = AnchorEntity(world: [camera.x, camera.y, camera.z])
        let perspectiveCamera = PerspectiveCamera()
        cameraAnchor.addChild(perspectiveCamera)
        self.scene.addAnchor(cameraAnchor)
        
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
        model.move(to: Transform(translation: [car.positions[car.count].x, car.positions[car.count].y, car.positions[car.count].z]), relativeTo: nil, duration: car.positions[car.count].duration, timingFunction: .linear)
        car.count += 1
    }
    
    private func tracePath(prev: (x: Float, y: Float, z: Float, duration: Double), now: (x: Float, y: Float, z: Float, duration: Double), color: UIColor) {
            
        let position1 = SIMD3(x: prev.x, y: prev.y, z: prev.z)
        let position2 = SIMD3(x: now.x, y: now.y, z: now.z)
        
        let midPosition = SIMD3(x:(position1.x + position2.x) / 2,
                                y:(position1.y + position2.y) / 2,
                                z:(position1.z + position2.z) / 2)
            
        let anchor = AnchorEntity()
        anchor.position = midPosition
        anchor.look(at: position1, from: midPosition, relativeTo: nil)
        
        let meters = simd_distance(position1, position2)
        
        let lineMaterial = SimpleMaterial.init(color: color,
                                               roughness: 1,
                                               isMetallic: false)
        
        let bottomLineMesh = MeshResource.generateBox(width:0.025,
                                                      height: 0.01,
                                                      depth: meters)
        
        let bottomLineEntity = ModelEntity(mesh: bottomLineMesh,
                                           materials: [lineMaterial])
        
        bottomLineEntity.position = .init(0, 0.025, 0)
        anchor.addChild(bottomLineEntity)
        self.scene.addAnchor(anchor)
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }

    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
