//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import SceneKit
import Accelerate

class CameraPosition {
    // Stores the x, y and z angles for the cameraPos
    var coords = SCNVector3(x: 0, y: 3, z: 15)
    let radius: Float = 15 // Radius of the sphere in which the camera moves around car
}

struct SinglePosition { // Stores one set of coordinates of a car at a given time from the start of the lap
    var coords: SCNVector3 // Current coordinate of car
    var timestamp: Double // No. of seconds since the start of the lap
    
    /*
     No. of seconds the car took to get to this coordinate from the previous coordinate.
     Defaults to 0 since the number of total positions changes during resampling.
     Hence, delta between this and last coord can only be calculated once resampling is finished.
    */
    var duration: Double = 0
    var interpolated: Bool = false // True if the coord was calculated via interpolation
    
    // Any position will be sorted in chronological order
    static func <(lhs: SinglePosition, rhs: SinglePosition) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}

class CarPositions { // Contains all the positions of a given car for a given lap
    var positions: [SinglePosition] = []
}

struct LapComparisonView: View {
    
    let selectedDriverAndLaps: (car1: (driver: String, lap: Int), car2: (driver: String, lap: Int)) // Initialised by caller of view
    
    @EnvironmentObject var processor: DataProcessor
    @State var car1Pos = CarPositions()
    @State var car2Pos = CarPositions()
    @State var cameraPos = CameraPosition()

    @State var dataLoaded: Bool = false
    
    var body: some View {
        if dataLoaded {
            sceneView
        } else {
            VStack {}
                .onAppear {
                    self.getRawPositions(driver: selectedDriverAndLaps.car1.driver, lap: selectedDriverAndLaps.car1.lap, dataStore: car1Pos)
                    self.getRawPositions(driver: selectedDriverAndLaps.car2.driver, lap: selectedDriverAndLaps.car2.lap, dataStore: car2Pos)
                    
                    self.resample(reference: car1Pos, target: car2Pos)
                    self.resample(reference: car2Pos, target: car1Pos)

                    self.smoothConvolve(carPos: car1Pos)
                    self.smoothConvolve(carPos: car2Pos)
                    
                    self.calculateDurations(carPos: car1Pos)
                    self.calculateDurations(carPos: car2Pos)
                    
                    // TODO: Change this to an error being thrown that notifies user
                    if (!car1Pos.positions.isEmpty) && (!car2Pos.positions.isEmpty) {
                        dataLoaded = true
                    }
            }
        }
    }
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
//    @State private var prevY: Double = 0
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let xModifier: Float = 0.05 // Scales gesture distance to change in coords of cameraPos
//    private let yModifier: Float = 0.0001
    
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
        
    private func getRawPositions(driver: String, lap: Int, dataStore: CarPositions) {
        
        // Load position data stored in the driverDatabase. If driver/lap provided does not exist, default value is an empty array
        let posData = processor.driverDatabase[driver]?.laps[String(lap)]?.PositionData ?? []
        // If no position data is available for the lap, or the lap does not exist, throw an error
        if posData.count == 0 {
            return // TODO: Throw an error instead of simply returning?
        }
        
        // Loop through the raw position data array and store data inside CarPositions class
        for i in 0...(posData.count - 1) {
            let coords = posData[i].value.components(separatedBy: ",")
            if coords[0] == "OnTrack" { // Kafka also broadcasts OffTrack coords which we can ignore
                // All coords are divided by 10 since F1 provides data that is accurate to 1/10th of a meter.
                let x = (Float(coords[1]) ?? 0) / 10
                let y = (Float(coords[3]) ?? 0) / 10 // y and z coords are swapped between F1 live data and SceneKit
                let z = (Float(coords[2]) ?? 0) / 10
                
                dataStore.positions.append(
                    SinglePosition(coords: SCNVector3(x: x, y: y, z: z), timestamp: posData[i].timestamp - posData[0].timestamp)
                ) // Timestamp will be 0 for the first position
            }
        }
    }
    
    private func calculateDurations(carPos: CarPositions) {
        // Once all resampling is done, calculate final durations
        for i in 1...(carPos.positions.count - 1) {
            carPos.positions[i].duration = carPos.positions[i].timestamp - carPos.positions[i-1].timestamp
        }
    }
    
    private func resample(reference: CarPositions, target: CarPositions) {
        /*
         Resampling ensures that both cars will have the same number of position data points. There is no loss of accuracy
         when resampling as linear interpolation is done between non-interpolated data to calculate missing data points. This would have
         otherwise been done anyway since the SCNAction.move(duration:) is a linear animation.
         
         The resampled data ensures that both cars will have SCNAction.move() being called in parallel and for the same number of
         times, preventing processing delays from adding up and diverging the gap between the cars.
         
         All timestamps in reference will be added to target, if not already present.
        */
        
        for refItem in reference.positions {
            let index = target.positions.insertionIndexOf(elem: refItem) {$0 < $1} // target.positions is sorted in chronological order
            if index > (target.positions.count - 1) {
                /*
                 The first and last coords are considered to be absolute values. Hence, if reference has more data points than target, the
                 last coord of target is duplicated.
                */
                target.positions.append(SinglePosition(coords: target.positions.last?.coords ?? SCNVector3(), timestamp: refItem.timestamp))
            } else if target.positions[index].timestamp != refItem.timestamp { // Only interpolate if data does not already exist
                target.positions.insert(SinglePosition(coords: SCNVector3(), timestamp: refItem.timestamp), at: index)
                target.positions[index].interpolated = true
            }
        }
        self.fillMissing(carPos: target)
    }
    
    private func fillMissing(carPos: CarPositions) {
        /*
         Any data point that is marked with interpolated == true will have it's coordinate calculated via linear interpolation between
         the previous coordinate and the next non-interpolated coordinate.
        */
        for i in 0...(carPos.positions.count - 1) {
            if carPos.positions[i].interpolated == true {
                var j = i
                while j < carPos.positions.count { // Finding next non-interpolated data point
                    if carPos.positions[j].interpolated == false {
                        carPos.positions[i].coords = self.linearInterpolate(prev: carPos.positions[i-1], next: carPos.positions[j], t: Float(carPos.positions[i].timestamp))
                        break
                    } else {
                        j += 1
                    }
                }
            }
        }
    }
    
    private func linearInterpolate(prev: SinglePosition, next: SinglePosition, t: Float) -> SCNVector3 {
        /*
         t: Float is the timestamp for which the unknown coord should be calculated. The linear equation of a line formed by
         (time1, x1/y1/z1) and (time2, x2/y2/z2) is calculated using subtraction method of solving simult. eqns.
        */
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
            x = (t - c) / m
        }
        
        // Solving y
        if (prev.coords.y - next.coords.y).isNearlyEqual(to: 0) {
            y = prev.coords.y
        } else {
            m = numerator / (prev.coords.y - next.coords.y)
            c = Float(prev.timestamp) - (m * prev.coords.y)
            y = (t - c) / m
        }
        
        // Solving z
        if (prev.coords.z - next.coords.z).isNearlyEqual(to: 0) {
            z = prev.coords.z
        } else {
            m = numerator / (prev.coords.z - next.coords.z)
            c = Float(prev.timestamp) - (m * prev.coords.z)
            z = (t - c) / m
        }
        
        return SCNVector3(x: Float(x), y: Float(y), z: Float(z))
    }
    
    private func smoothConvolve(carPos: CarPositions) {
        var xSmooth: [Float] = []
        var ySmooth: [Float] = []
        var zSmooth: [Float] = []
        var tSmooth: [Float] = []

        for i in 0...(carPos.positions.count - 1) {
            xSmooth.append(carPos.positions[i].coords.x)
            ySmooth.append(carPos.positions[i].coords.y)
            zSmooth.append(carPos.positions[i].coords.z)
            tSmooth.append(Float(carPos.positions[i].timestamp))
        }

        xSmooth = vDSP.convolve(xSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        ySmooth = vDSP.convolve(ySmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        zSmooth = vDSP.convolve(zSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        tSmooth = vDSP.convolve(tSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])

        for i in 0...(xSmooth.count - 1) {
            carPos.positions[i].coords.x = xSmooth[i]
            carPos.positions[i].coords.y = ySmooth[i]
            carPos.positions[i].coords.z = zSmooth[i]
            carPos.positions[i].timestamp = Double(tSmooth[i])
        }
    }
}
