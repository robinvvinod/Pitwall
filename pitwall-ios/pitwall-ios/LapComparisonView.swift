//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import RealityKit
import Combine

class Camera {
    // Stores the x, y and z angles for the camera
    var x: Float = 0
    var y: Float = 0.5
    var z: Float = 3
}

class CarPositions {
    var positions: [(x: Float, y: Float, z: Float, duration: Double)] = [(0,0,0,0)]
    var count: Int = 0
}

struct LapComparisonView: View {

    @EnvironmentObject var processor: DataProcessor
    let selectedDriverAndLaps: (car1: (driver: String, lap: Int), car2: (driver: String, lap: Int))
    @State var car1Pos = CarPositions()
    @State var car2Pos = CarPositions()
    @State var flag: Bool = false
        
    @State private var camera = Camera()
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var prevY: Double = 0
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let radius: Float = 3 // Radius of rotation of camera around y-axis
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of camera
    private let yModifier: Float = 0.0001
    
    var body: some View {
        if flag {
            arView
        } else {
            VStack {}.onAppear {
                getRawPositions(driver: selectedDriverAndLaps.car1.driver, lap: selectedDriverAndLaps.car1.lap, dataStore: car1Pos)
                getRawPositions(driver: selectedDriverAndLaps.car2.driver, lap: selectedDriverAndLaps.car2.lap, dataStore: car2Pos)
                flag = true
            }
        }
    }
    
    private func getRawPositions(driver: String, lap: Int, dataStore: CarPositions) {
        let posData = processor.driverDatabase[driver]?.laps[String(lap)]?.PositionData ?? []
        if posData.count == 0 {
            return
        }
        for i in 0...(posData.count - 1) {
            let coords = posData[i].value.components(separatedBy: ",")
            if coords[0] == "OnTrack" {
                let x = (Float(coords[1]) ?? 0) / 10
                let y = (Float(coords[3]) ?? 0) / 10
                let z = (Float(coords[2]) ?? 0) / 10
                
                if i == 0 {
                    dataStore.positions.removeFirst()
                    dataStore.positions.append((x: x, y: y, z: z, duration: Double(0)))
                } else {
                    dataStore.positions.append((x: x, y: y, z: z, duration: (posData[i].timestamp - posData[i-1].timestamp)))
                }
            }
        }
    }
    
    var arView: some View {
        ARViewContainer(camera: $camera, car1Pos: car1Pos, car2Pos: car2Pos)
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
