//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import RealityKit
import SceneKit
import Charts
import Accelerate

class CameraPosition {
    // Stores the x, y and z angles for the cameraPos
    var coords = SCNVector3(x: 0, y: 3, z: 15)
    let radius: Float = 15
}

struct SinglePosition {
    var coords: SCNVector3
    var duration: Double = 0
    var timestamp: Double
    var interpolated: Bool = false
    
    static func <(lhs: SinglePosition, rhs: SinglePosition) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}

class CarPositions {
    var positions: [SinglePosition] = []
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
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of cameraPos
    private let yModifier: Float = 0.0001
    
    var body: some View {
        if dataLoaded {
            sceneView
//            Chart {
//                ForEach(0...(car2Pos.positions.count - 1), id: \.self) { i in
//                    LineMark(x: .value("t", car2Pos.positions[i].timestamp), y: .value("x", car2Pos.positions[i].coords.x))
//                        .foregroundStyle(.blue)
//                    LineMark(x: .value("t", car2Pos.positions[i].timestamp), y: .value("z", car2Pos.positions[i].coords.z))
//                        .foregroundStyle(.orange)
//                }
                
//                ForEach(0...(car1Pos.positions.count - 1), id: \.self) { i in
//                    LineMark(x: .value("t", car1Pos.positions[i].timestamp), y: .value("x", car1Pos.positions[i].coords.x))
//                        .foregroundStyle(.green)
//                    LineMark(x: .value("t", car1Pos.positions[i].timestamp), y: .value("z", car1Pos.positions[i].coords.z))
//                        .foregroundStyle(.yellow)
//
//                }
                
//            }
        } else {
            VStack {}
                .onAppear {
                    self.getRawPositions(driver: selectedDriverAndLaps.car1.driver, lap: selectedDriverAndLaps.car1.lap, dataStore: car1Pos)
                    self.getRawPositions(driver: selectedDriverAndLaps.car2.driver, lap: selectedDriverAndLaps.car2.lap, dataStore: car2Pos)
                    
                    self.resample(reference: car1Pos, target: car2Pos)
                    self.resample(reference: car2Pos, target: car1Pos)
                    
                    self.calculateDurations(carPos: car1Pos)
                    self.calculateDurations(carPos: car2Pos)
                    
                    var xSmooth: [Float] = []
                    var ySmooth: [Float] = []
                    var zSmooth: [Float] = []
                    var tSmooth: [Float] = []
                    
                    for i in 0...(car2Pos.positions.count - 1) {
                        xSmooth.append(car2Pos.positions[i].coords.x)
                        ySmooth.append(car2Pos.positions[i].coords.y)
                        zSmooth.append(car2Pos.positions[i].coords.z)
                        tSmooth.append(Float(car2Pos.positions[i].timestamp))
                    }
                    
                    xSmooth = vDSP.convolve(xSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    ySmooth = vDSP.convolve(ySmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    zSmooth = vDSP.convolve(zSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    tSmooth = vDSP.convolve(tSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    
                    for i in 0...(xSmooth.count - 1) {
                        car2Pos.positions[i].coords.x = xSmooth[i]
                        car2Pos.positions[i].coords.y = ySmooth[i]
                        car2Pos.positions[i].coords.z = zSmooth[i]
                        car2Pos.positions[i].timestamp = Double(tSmooth[i])
                    }
                    
                    xSmooth = []
                    ySmooth = []
                    zSmooth = []
                    tSmooth = []
                    
                    for i in 0...(car1Pos.positions.count - 1) {
                        xSmooth.append(car1Pos.positions[i].coords.x)
                        ySmooth.append(car1Pos.positions[i].coords.y)
                        zSmooth.append(car1Pos.positions[i].coords.z)
                        tSmooth.append(Float(car1Pos.positions[i].timestamp))
                    }
                    
                    xSmooth = vDSP.convolve(xSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    ySmooth = vDSP.convolve(ySmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    zSmooth = vDSP.convolve(zSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    tSmooth = vDSP.convolve(tSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
                    
                    for i in 0...(xSmooth.count - 1) {
                        car1Pos.positions[i].coords.x = xSmooth[i]
                        car1Pos.positions[i].coords.y = ySmooth[i]
                        car1Pos.positions[i].coords.z = zSmooth[i]
                        car1Pos.positions[i].timestamp = Double(tSmooth[i])
                    }
                    
                    if (!car1Pos.positions.isEmpty) && (!car2Pos.positions.isEmpty) {
                        dataLoaded = true
                    }
            }
        }
    }
    
    private func getRawPositions(driver: String, lap: Int, dataStore: CarPositions) {
        let posData = processor.driverDatabase[driver]?.laps[String(lap)]?.PositionData ?? []
        if posData.count == 0 {
            return
        }
        for i in 0..<posData.count {
            let coords = posData[i].value.components(separatedBy: ",")
            if coords[0] == "OnTrack" {
                let x = (Float(coords[1]) ?? 0) / 10
                let y = (Float(coords[3]) ?? 0) / 10 // y and z coords are swapped between F1 live data and RealityKit
                let z = (Float(coords[2]) ?? 0) / 10
                
                if i == 0 {
                    dataStore.positions.append(SinglePosition(coords: SCNVector3(x: x, y: y, z: z), timestamp: 0.0))
                } else {
                    dataStore.positions.append(SinglePosition(coords: SCNVector3(x: x, y: y, z: z), timestamp: posData[i].timestamp - posData[0].timestamp))
                }
            }
        }
    }
    
    private func calculateDurations(carPos: CarPositions) {
        for i in 0..<carPos.positions.count {
            if i != 0 {
                carPos.positions[i].duration = carPos.positions[i].timestamp - carPos.positions[i-1].timestamp
            }
        }
    }
    
    private func resample(reference: CarPositions, target: CarPositions) {
        for refItem in reference.positions {
            let index = target.positions.insertionIndexOf(elem: refItem) {$0 < $1}
            if index > (target.positions.count - 1) {
                target.positions.append(SinglePosition(coords: target.positions.last?.coords ?? SCNVector3(), timestamp: refItem.timestamp))
                target.positions[index].interpolated = true
            } else if target.positions[index].timestamp != refItem.timestamp {
                target.positions.insert(SinglePosition(coords: SCNVector3(), timestamp: refItem.timestamp), at: index)
                target.positions[index].interpolated = true
            }
        }
        self.fillMissing(carPos: target)
    }
    
    private func fillMissing(carPos: CarPositions) {
        for i in 0..<carPos.positions.count {
            if carPos.positions[i].interpolated == true {
                var j = i
                while j < carPos.positions.count {
                    if carPos.positions[j].interpolated == false {
                        carPos.positions[i].coords = self.interpolate(prev: carPos.positions[i-1], next: carPos.positions[j], t: carPos.positions[i].timestamp)
                        break
                    } else {
                        j += 1
                    }
                }
            }
        }
    }
    
    private func interpolate(prev: SinglePosition, next: SinglePosition, t: Double) -> SCNVector3 {
        let numerator = Float(prev.timestamp - next.timestamp)
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var m: Float = 0
        var c: Float = 0
        
        // Solving x
        if (prev.coords.x - next.coords.x).isNearlyEqual(to: 0) {
            x = prev.coords.x
        } else {
            m = numerator / (prev.coords.x - next.coords.x)
            c = Float(prev.timestamp) - (m * prev.coords.x)
            x = (Float(t) - c) / m
        }
        
        // Solving y
        if (prev.coords.y - next.coords.y).isNearlyEqual(to: 0) {
            y = prev.coords.y
        } else {
            m = numerator / (prev.coords.y - next.coords.y)
            c = Float(prev.timestamp) - (m * prev.coords.y)
            y = (Float(t) - c) / m
        }
        
        // Solving z
        if (prev.coords.z - next.coords.z).isNearlyEqual(to: 0) {
            z = prev.coords.z
        } else {
            m = numerator / (prev.coords.z - next.coords.z)
            c = Float(prev.timestamp) - (m * prev.coords.z)
            z = (Float(t) - c) / m
        }
        
        return SCNVector3(x: Float(x), y: Float(y), z: Float(z))
    }
    
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
                            This block ensures that cameraPos.coords.x is always within [-cameraPos.radius, cameraPos.radius]
                            If cameraPos.coords.x > cameraPos.radius, cameraPos.coords.x will decrease until -cameraPos.radius
                            If cameraPos.coords.x < -cameraPos.radius, cameraPos.coords.x will increase until cameraPos.radius
                            Direction of change is determined by zSign

                            This allows for "rolling" over of cameraPos.coords.x when crossing boundary points
                        */
                         if (cameraPos.coords.x > cameraPos.radius) && (zSign == true) {
                            zSign = false
                            cameraPos.coords.x = cameraPos.radius
                        } else if (cameraPos.coords.x > cameraPos.radius) && (zSign == false) {
                            zSign = true
                            cameraPos.coords.x = cameraPos.radius
                        } else if (cameraPos.coords.x < -cameraPos.radius) && (zSign == true) {
                            zSign = false
                            cameraPos.coords.x = -cameraPos.radius
                        } else if (cameraPos.coords.x < -cameraPos.radius) && (zSign == false) {
                            zSign = true
                            cameraPos.coords.x = -cameraPos.radius
                        }

//                        if cameraPos.coords.y > cameraPos.radius {
//                            cameraPos.coords.y = cameraPos.radius
//                        } else if cameraPos.coords.y < 0.05 {
//                            cameraPos.coords.y = 0.05
//                        }

                        // If zSign is -ve, cameraPos is "behind" the point of reference and cameraPos.coords.z should be negative
                        cameraPos.coords.z = zSign ? sqrt(pow(cameraPos.radius,2) - pow(cameraPos.coords.x, 2)) : -sqrt(pow(cameraPos.radius,2) - pow(cameraPos.coords.x, 2))
                    }
            )
    }
}
