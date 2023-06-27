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
    var coords = SCNVector3(x: -10, y: 10, z: 20)
    let radius: Float = 20 // Radius of the sphere in which the camera moves around car
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
    
    @EnvironmentObject private var processor: DataProcessor
    @State private var car1Pos = CarPositions()
    @State private var car2Pos = CarPositions()
    @State private var cameraPos = CameraPosition()
    @State private var car1Seq = SCNAction()
    @State private var car2Seq = SCNAction()
    @State private var trackNode = SCNNode()

    @State private var dataLoaded: Bool = false
    
    var body: some View {
        if dataLoaded {
            sceneView
        } else {
            VStack {}
                .onAppear {
                    // TODO: Do work in non-main thread
                    getRawPositions(driver: selectedDriverAndLaps.car1.driver, lap: selectedDriverAndLaps.car1.lap, dataStore: car1Pos)
                    getRawPositions(driver: selectedDriverAndLaps.car2.driver, lap: selectedDriverAndLaps.car2.lap, dataStore: car2Pos)
                                        
                    resampleToFrequency(target: car1Pos, frequency: 10)
                    resampleToFrequency(target: car2Pos, frequency: 10)
                    
                    savitskyGolayFilter(carPos: car1Pos)
                    savitskyGolayFilter(carPos: car2Pos)
                    
                    trackNode = SCNPathNode(path: car1Pos.positions.map { $0.coords }, width: 12, curvePoints: 32)
                                        
                    calculateDurations(carPos: car1Pos)
                    calculateDurations(carPos: car2Pos)

                    car1Seq = generateActionSequence(carPos: car1Pos)
                    car2Seq = generateActionSequence(carPos: car2Pos)
                    
                    // carPos is no longer needed after action sequence is created. Deallocating memory
                    car1Pos = CarPositions()
                    car2Pos = CarPositions()
                    
                    // TODO: Handle an error being thrown that notifies user
                    dataLoaded = true
            }
        }
    }
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let xModifier: Float = 0.5 // Scales gesture distance to change in coords of cameraPos
    
    var sceneView: some View {
        let scene = ComparisonScene(car1Seq: car1Seq, car2Seq: car2Seq, cameraPos: cameraPos, trackNode: trackNode)
        return SceneView(scene: scene, options: [.rendersContinuously], delegate: scene)
            .gesture(
                DragGesture()
                    .onChanged { translate in

                        if translate.translation.width > prevX { // Moving to the east
                            cameraPos.coords.x += zSign ? xModifier : -xModifier // controls direction of magnitude change of cameraPos.coords.x
                        } else {
                            cameraPos.coords.x += zSign ? -xModifier : xModifier
                        }

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

                        // If zSign is -ve, cameraPos is "behind" the point of reference and cameraPos.coords.z should be negative
                        cameraPos.coords.z = zSign ? sqrt(pow(cameraPos.radius,2) - pow(cameraPos.coords.x, 2)) : -sqrt(pow(cameraPos.radius,2) - pow(cameraPos.coords.x, 2))
                    }
            )
    }
        
    private func getRawPositions(driver: String, lap: Int, dataStore: CarPositions) {
        // Load position data stored in the driverDatabase. If driver/lap provided does not exist, default value is an empty array
        let posData = processor.driverDatabase[driver]?.laps[String(lap)]?.PositionData ?? []
        
        if posData.count == 0 { // If no position data is available for the lap, or the lap does not exist, throw an error
            return // TODO: Throw an error instead of simply returning?
        }
        
        // Loop through the raw position data array and store data inside CarPositions class
        for i in 0...(posData.count - 1) {
            let coords = posData[i].value.components(separatedBy: ",")
            if coords[0] == "OnTrack" { // Kafka also broadcasts OffTrack coords which we can ignore
                // All coords are divided by 10 since F1 provides data that is accurate to 1/10th of a meter.
                let x = (Float(coords[1]) ?? 0) / -10 // - sign is added as Scenekit directions are inverted compared to F1 data
                let y = (Float(coords[3]) ?? 0) / 10 // y and z coords are swapped between F1 live data and SceneKit
                let z = (Float(coords[2]) ?? 0) / 10
                
                dataStore.positions.append(
                    SinglePosition(coords: SCNVector3(x: x, y: y, z: z), timestamp: posData[i].timestamp - posData[0].timestamp)
                )
            }
        }
    }
    
    private func resampleToReference(reference: CarPositions, target: CarPositions) {
        /*
         All timestamps in reference will be added to target, if not already present.
         
         Resampling ensures that both cars will have the same number of position data points. There is no loss of accuracy
         when resampling as linear interpolation is done between non-interpolated data to calculate missing data points. This would have
         been done anyway since the SCNAction.move(duration:) is a linear animation. Loss of accuracy comes during the smoothing of data.
         
         The resampled data ensures that both cars will have SCNAction.move() being called in parallel and for the same number of
         times, preventing processing delays from adding up and diverging the gap between the cars.
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
        fillMissing(carPos: target)
    }
    
    private func resampleToFrequency(target: CarPositions, frequency: Double) {
        /*
         Resamples data to the specified frequency (Hz). First and last data points are kept intact. Refer to
         resampleToReference() for explanation on why resampling is necessary
        */
        
        let lastTimestamp = target.positions.last?.timestamp ?? 0
        var curTime = 1 / frequency
        
        while curTime < lastTimestamp {
            let item = SinglePosition(coords: SCNVector3(), timestamp: curTime, interpolated: true)
            let index = target.positions.insertionIndexOf(elem: item) {$0 < $1}
            target.positions.insert(item, at: index)
            curTime += 0.1
        }
        
        fillMissing(carPos: target)
        
        // Preserve first and last data points. All other non-interpolated data is removed
        for i in stride(from: target.positions.count - 2, to: 1, by: -1) {
            if target.positions[i].interpolated == false {
                target.positions.remove(at: i)
            }
        }
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
                        carPos.positions[i].coords = linearInterpolate(prev: carPos.positions[i-1], next: carPos.positions[j], t: Float(carPos.positions[i].timestamp))
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
         
         m is gradient, c is y-intercept
         t₁ = mx₁ + c --> (1)
         t₂ = mx₂ + c --> (2)
         (1) - (2)
         m = (t₁ - t₂) / (x₁ - x₂)
         c = (t₁ - mx₁)
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
        
        return SCNVector3(x: x, y: y, z: z)
    }
    
    private func smoothConvolve(carPos: CarPositions) {
        var xSmooth: [Float] = []
        var ySmooth: [Float] = []
        var zSmooth: [Float] = []

        for i in 0...(carPos.positions.count - 1) {
            xSmooth.append(carPos.positions[i].coords.x)
            ySmooth.append(carPos.positions[i].coords.y)
            zSmooth.append(carPos.positions[i].coords.z)
        }
        
        // Padding to ensure output is same size as input
        xSmooth = [Float](repeating: xSmooth[0], count: 9) + xSmooth
        ySmooth = [Float](repeating: ySmooth[0], count: 9) + ySmooth
        zSmooth = [Float](repeating: zSmooth[0], count: 9) + zSmooth
        
        xSmooth = vDSP.convolve(xSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        ySmooth = vDSP.convolve(ySmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        zSmooth = vDSP.convolve(zSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        
        for i in 0...(xSmooth.count - 1) {
            carPos.positions[i].coords.x = xSmooth[i]
            carPos.positions[i].coords.y = ySmooth[i]
            carPos.positions[i].coords.z = zSmooth[i]
        }
    }
    
    private func savitskyGolayFilter(carPos: CarPositions) {
        /*
         A Savitsky-Golay filter is applied to the resampled position data to smooth out noise in the data. The filter
         is applied within a window length of 20 (~1s before & after current point is used to calculate current point) and a
         polyorder of 2 (quadratic).
         
         https://en.wikipedia.org/wiki/Savitzky%E2%80%93Golay_filter
         For equally spaced data points, an analytical solution to the least-squares equations can be found, in the form of the
         convolution coefficients.
         
         NOTE: Can only be used if data is equally spaced. Call resampleToFrequency() before calling this function.
        */
        
        var xSmooth: [Float] = []
        var ySmooth: [Float] = []
        var zSmooth: [Float] = []

        for i in 0...(carPos.positions.count - 1) {
            xSmooth.append(carPos.positions[i].coords.x)
            ySmooth.append(carPos.positions[i].coords.y)
            zSmooth.append(carPos.positions[i].coords.z)
        }

        // Padding to nearest boundary values to ensure output is same size as input
        xSmooth = [Float](repeating: xSmooth[0], count: 10) + xSmooth + [Float](repeating: xSmooth[xSmooth.count - 1], count: 10)
        ySmooth = [Float](repeating: ySmooth[0], count: 10) + ySmooth + [Float](repeating: ySmooth[ySmooth.count - 1], count: 10)
        zSmooth = [Float](repeating: zSmooth[0], count: 10) + zSmooth + [Float](repeating: zSmooth[zSmooth.count - 1], count: 10)
        
        // Savitsky Golay coefficients calculated using window length = 20, polyorder = 2
        let kernel: [Float] = [-0.05795455,-0.02386364,0.00643939,0.03295455,0.05568182,0.07462121,0.08977273,0.10113636,0.10871212,0.1125,0.1125,0.10871212,0.10113636,0.08977273,0.07462121,0.05568182,0.03295455,0.00643939,-0.02386364,-0.05795455]
        
        xSmooth = vDSP.convolve(xSmooth, withKernel: kernel)
        ySmooth = vDSP.convolve(ySmooth, withKernel: kernel)
        zSmooth = vDSP.convolve(zSmooth, withKernel: kernel)
        
        for i in 0...(xSmooth.count - 1) {
            carPos.positions[i].coords.x = xSmooth[i]
            carPos.positions[i].coords.y = ySmooth[i]
            carPos.positions[i].coords.z = zSmooth[i]
        }
    }
    
    private func calculateDurations(carPos: CarPositions) {
        // Once all resampling is done, calculate final durations
        for i in 1...(carPos.positions.count - 1) {
            carPos.positions[i].duration = carPos.positions[i].timestamp - carPos.positions[i-1].timestamp
        }
    }
    
    private func generateActionSequence(carPos: CarPositions) -> SCNAction {
        var seq: [SCNAction] = []
        for i in 1...(carPos.positions.count - 1) {
            /*
             These placeholder vars are needed to avoid the lookWithDurationAction block from using reference-type values of x,y,z from
             the carPos instance at the time the action is called, instead of the values when the block is instantiated.
            */
            let x = carPos.positions[i].coords.x
            let y = carPos.positions[i].coords.y
            let z = carPos.positions[i].coords.z
            let dur = carPos.positions[i].duration

            /*
             Every action in the sequence is a grouped action comprising of the move to the current coordinate and the rotation of the car
             (if present) to look at the destination coordinate. These 2 actions are exectured in parallel.
            */
            
            let lookWithDurationAction = SCNAction.run { node in
                SCNTransaction.begin()
                SCNTransaction.animationDuration = dur
                node.look(at: SCNVector3(x: x, y: y, z: z), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
                SCNTransaction.commit()
            }

            let group = SCNAction.group([
                SCNAction.move(to: SCNVector3(x: x, y: y, z: z), duration: dur),
                lookWithDurationAction
            ])
            seq.append(group)
        }
        return SCNAction.sequence(seq)
    }
}
