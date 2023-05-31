//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import RealityKit

struct Camera {
    // Stores the x, y and z angles for the camera
    var x: Float = 0
    var y: Float = 0.5
    var z: Float = 3
}

struct Car {
    // Stores the x, y coords of cars
    var x: Float = 0
    var y: Float = 0
}

struct Cars {
    var car1 = Car()
    var car2 = Car()
}

struct LapComparisonView: View {

    @State private var cars = Cars()
    @State private var camera = Camera()
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var prevY: Double = 0
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let radius: Float = 3 // Radius of rotation of camera around y-axis
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of camera
    private let yModifier: Float = 0.0001

    
    var body: some View {
        Button("MOVE") {
            cars.car1.x += 1
        }
        ARViewContainer(camera: $camera, cars: $cars)
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
                        camera.z = zSign ? sqrt(powf(radius,2) - powf(camera.x, 2)) : -sqrt(powf(radius,2) - powf(camera.x, 2))
                    }
            )
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var camera: Camera
    @Binding var cars: Cars

    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.debugOptions = .showWorldOrigin

        let newAnchor = AnchorEntity(world: [0, 0, 0])
        let newSphere = ModelEntity(mesh: .generateSphere(radius: 0.3))
        newAnchor.addChild(newSphere)
        arView.scene.anchors.append(newAnchor)
        
        let cameraAnchor = AnchorEntity(world: [camera.x, camera.y, camera.z])
        let camera = PerspectiveCamera()
        cameraAnchor.addChild(camera)
        arView.scene.anchors.append(cameraAnchor)
                    
        return arView

    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.scene.anchors[0].move(to: Transform(translation: [cars.car1.x, 0, cars.car1.y]), relativeTo: nil, duration: 10)
        uiView.scene.anchors[1].move(to: Transform(translation: [camera.x, camera.y, camera.z]), relativeTo: uiView.scene.anchors[0])
        uiView.scene.anchors[1].look(at: uiView.scene.anchors[0].position(relativeTo: nil), from: uiView.scene.anchors[1].position(relativeTo: nil), upVector: [0, 1, 0], relativeTo: nil)
    }
}
