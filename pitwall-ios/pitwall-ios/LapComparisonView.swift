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

    @State private var cars = Cars()
    @State private var camera = Camera()
    @State private var duration: Double = 0
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var prevY: Double = 0
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let radius: Float = 3 // Radius of rotation of camera around y-axis
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of camera
    private let yModifier: Float = 0.0001
    
    var body: some View {
        Button("MOVE") {
            duration = 10
            cars.car1.x += 1
        }
        
        ARViewContainer(camera: $camera, cars: $cars, duration: $duration)
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
    @Binding var cars: Cars
    @Binding var duration: Double
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = CustomARView(frame: .zero, camera: camera)
        arView.cameraMode = .nonAR
        arView.automaticallyConfigureSession = false
        arView.debugOptions = .showWorldOrigin

        let newAnchor = AnchorEntity(world: [0, 0, 0])
        let newSphere = ModelEntity(mesh: .generateSphere(radius: 0.3))
        newAnchor.addChild(newSphere)
        arView.scene.anchors.append(newAnchor)
        
        let cameraAnchor = AnchorEntity(world: [camera.x, camera.y, camera.z])
        let perspectiveCamera = PerspectiveCamera()
        cameraAnchor.addChild(perspectiveCamera)
        arView.scene.anchors.append(cameraAnchor)
                                            
        return arView

    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.scene.anchors[0].move(to: Transform(translation: [cars.car1.x, 0, cars.car1.y]), relativeTo: nil, duration: duration)
    }
}

class CustomARView: ARView {
    
    private var subscription: AnyCancellable?
        
    required init(frame: CGRect, camera: Camera) {
        super.init(frame: frame)
        
        subscription = scene.publisher(for: SceneEvents.Update.self, on: nil).sink(receiveValue: { _ in
            super.scene.anchors[1].move(to: Transform(translation: [camera.x, camera.y, camera.z]), relativeTo: super.scene.anchors[0])
            super.scene.anchors[1].look(at: super.scene.anchors[0].position(relativeTo: nil), from: super.scene.anchors[1].position(relativeTo: nil), upVector: [0, 1, 0], relativeTo: nil)
        })
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

struct Cars {
    struct Car {
        // Stores the x, y coords of cars
        var x: Float = 0
        var y: Float = 0
    }
    
    var car1 = Car()
    var car2 = Car()
}
