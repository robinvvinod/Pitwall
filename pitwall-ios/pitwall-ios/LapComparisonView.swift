//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import RealityKit
import SceneKit

class CameraPosition {
    // Stores the x, y and z angles for the cameraPos
    var coords = SCNVector3(x: 0, y: 1.5, z: 5)
}

class CarPositions {
    var positions: [(coords: SCNVector3, duration: Double)] = []
    var count: Int = 0
}

struct LapComparisonView: View {
    
    let selectedDriverAndLaps: (car1: (driver: String, lap: Int), car2: (driver: String, lap: Int))
    
    @EnvironmentObject var processor: DataProcessor
    @State var car1Pos = CarPositions()
    @State var car2Pos = CarPositions()
    @State var cameraPos = CameraPosition()

    @State var dataLoaded: Bool = false
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var prevY: Double = 0
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let radius: Float = 5 // Radius of rotation of cameraPos around y-axis
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of cameraPos
    private let yModifier: Float = 0.0001
    
    var body: some View {
        if dataLoaded {
            sceneView
        } else {
            VStack {}
                .onAppear {
                    getRawPositions(driver: selectedDriverAndLaps.car1.driver, lap: selectedDriverAndLaps.car1.lap, dataStore: car1Pos)
                    getRawPositions(driver: selectedDriverAndLaps.car2.driver, lap: selectedDriverAndLaps.car2.lap, dataStore: car2Pos)
                    dataLoaded = true
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
                let x = (Float(coords[1]) ?? 0) / 100
                let y = (Float(coords[3]) ?? 0) / 100 // y and z coords are swapped between F1 live data and RealityKit
                let z = (Float(coords[2]) ?? 0) / 100
                
                if i == 0 {
                    dataStore.positions.append((coords: SCNVector3(x: x, y: y, z: z), duration: Double(0)))
                } else {
                    dataStore.positions.append((coords: SCNVector3(x: x, y: y, z: z), duration: (posData[i].timestamp - posData[i-1].timestamp)))
                }
            }
        }
    }
    
//    private func interpolate(reference: CarPositions, target: CarPositions) -> CarPositions {
//        let res = CarPositions()
//        var count = 0
//        var referenceTimestamp: Double = 0
//        var targetTimestamp: Double = 0
//        for position in reference.positions {
//            if count == target.positions.count {
//                break
//            }
//
//            referenceTimestamp += position.duration
//            for i in count...(target.positions.count - 1) {
//                targetTimestamp += target.positions[i].duration
//                if targetTimestamp > referenceTimestamp {
//                    let interpolatedX = target.positions[i].x - ((target.positions[i].x - target.positions[i-1].x)/2)
//                    let interpolatedY = target.positions[i].y - ((target.positions[i].y - target.positions[i-1].y)/2)
//                    let interpolatedZ = target.positions[i].z - ((target.positions[i].z - target.positions[i-1].z)/2)
//                    res.positions.append((x: interpolatedX, y: interpolatedY, z: interpolatedZ, duration: position.duration))
//                } else {
//                    res.positions.append(target.positions[i])
//                }
//                count += 1
//            }
//        }
//
//        return res
//    }
    
    var sceneView: some View {
        let scene = ComparisonScene(car1Pos: car1Pos, car2Pos: car2Pos, cameraPos: cameraPos)
        return SceneView(scene: scene, options: [.rendersContinuously], delegate: scene)
            .gesture(
                DragGesture()
                    .onChanged { translate in

                        if translate.translation.width > prevX { // Moving to the east
                            cameraPos.coords.x += zSign ? xModifier : -xModifier // controls direction of magnitude change of cameraPos.coords.x
                        } else {
                            cameraPos.coords.x += zSign ? -xModifier : xModifier
                        }

//                        if translate.translation.height > prevY { // Moving to the north
//                            cameraPos.coords.y += yModifier * Float(abs(translate.translation.height - prevY))
//                        } else {
//                            cameraPos.coords.y -= yModifier * Float(abs(translate.translation.height - prevY))
//                        }

                        prevX = translate.translation.width

                        /*
                            This block ensures that cameraPos.coords.x is always within [-radius, radius]
                            If cameraPos.coords.x > radius, cameraPos.coords.x will decrease until -radius
                            If cameraPos.coords.x < -radius, cameraPos.coords.x will increase until radius
                            Direction of change is determined by zSign

                            This allows for "rolling" over of cameraPos.coords.x when crossing boundary points
                        */
                         if (cameraPos.coords.x > radius) && (zSign == true) {
                            zSign = false
                            cameraPos.coords.x = radius
                        } else if (cameraPos.coords.x > radius) && (zSign == false) {
                            zSign = true
                            cameraPos.coords.x = radius
                        } else if (cameraPos.coords.x < -radius) && (zSign == true) {
                            zSign = false
                            cameraPos.coords.x = -radius
                        } else if (cameraPos.coords.x < -radius) && (zSign == false) {
                            zSign = true
                            cameraPos.coords.x = -radius
                        }

//                        if cameraPos.coords.y > radius {
//                            cameraPos.coords.y = radius
//                        } else if cameraPos.coords.y < 0.05 {
//                            cameraPos.coords.y = 0.05
//                        }

                        // If zSign is -ve, cameraPos is "behind" the point of reference and cameraPos.coords.z should be negative
                        cameraPos.coords.z = zSign ? sqrt(pow(radius,2) - pow(cameraPos.coords.x, 2)) : -sqrt(pow(radius,2) - pow(cameraPos.coords.x, 2))
                    }
            )
    }
}
