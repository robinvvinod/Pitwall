//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import RealityKit
import Combine

struct LapComparisonView: View {

    @State private var camera = Camera()
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var prevY: Double = 0
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let radius: Float = 3 // Radius of rotation of camera around y-axis
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of camera
    private let yModifier: Float = 0.0001
    
    var body: some View {
        ARViewContainer(camera: $camera, car1Pos: CarPositions(positions: [(1,0,2)]), car2Pos: CarPositions(positions: [(1,0,1.8)]))
            .gesture(
                DragGesture()
                    .onChanged { translate in
                        
                        if translate.translation.width > prevX { // Moving to the east
                            camera.x += zSign ? xModifier : -xModifier // controls direction of magnitude change of camera.x
                        } else {
                            camera.x += zSign ? -xModifier : xModifier
                        }
                        
                        if translate.translation.height > prevY { // Moving to the north
                            camera.y += yModifier * Float(abs(translate.translation.height - prevY))
                        } else {
                            camera.y -= yModifier * Float(abs(translate.translation.height - prevY))
                        }
                        
                        prevX = translate.translation.width
                        
                        /*
                            This block ensures that camera.x is always within [-radius, radius]
                            If camera.x > radius, camera.x will decrease until -radius
                            If camera.x < -radius, camera.x will increase until radius
                            Direction of change is determined by zSign
                         
                            This allows for "rolling" over of camera.x when crossing boundary points
                        */
                         if (camera.x > radius) && (zSign == true) {
                            zSign = false
                            camera.x = radius
                        } else if (camera.x > radius) && (zSign == false) {
                            zSign = true
                            camera.x = radius
                        } else if (camera.x < -radius) && (zSign == true) {
                            zSign = false
                            camera.x = -radius
                        } else if (camera.x < -radius) && (zSign == false) {
                            zSign = true
                            camera.x = -radius
                        }
                        
                        if camera.y > radius {
                            camera.y = radius
                        } else if camera.y < 0.5 {
                            camera.y = 0.5
                        }
                        
                        // If zSign is -ve, camera is "behind" the point of reference and camera.z should be negative
                        camera.z = zSign ? sqrt(pow(radius,2) - pow(camera.x, 2)) : -sqrt(pow(radius,2) - pow(camera.x, 2))
                    }
            )
    }
}

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
            if self.car1Pos.count == self.car1Pos.positions.count - 1 {
                self.car1AnimationSub = nil
                return
            }
            self.nextMove(model: car1, car: self.car1Pos)
        })
        
        car2AnimationSub = scene.publisher(for: AnimationEvents.PlaybackCompleted.self, on: car2).sink(receiveValue: { _ in
            // Check if all movements are already done
            if self.car2Pos.count == self.car2Pos.positions.count - 1 {
                self.car2AnimationSub = nil
                return
            }
            self.nextMove(model: car2, car: self.car2Pos)
        })
        
        self.nextMove(model: car1, car: self.car1Pos)
        self.nextMove(model: car2, car: self.car2Pos)
    }
    
    private func nextMove(model: ModelEntity, car: CarPositions) {
        model.move(to: Transform(translation: [car.positions[car.count].x, 0, car.positions[car.count].y]), relativeTo: nil, duration: car.positions[car.count].duration, timingFunction: .linear)
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }

    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class Camera {
    // Stores the x, y and z angles for the camera
    var x: Float = 0
    var y: Float = 0.5
    var z: Float = 3
}

struct CarPositions {
    let positions: [(x: Float, y: Float, duration: Double)]
    var count: Int = 0
}
