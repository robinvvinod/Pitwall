//
//  LapComparisonViewModel.swift
//  pitwall-ios
//
//  Created by Robin on 2/7/23.
//

import Foundation
import SceneKit
import Accelerate
import SwiftUI

class LapSimulationViewModel {
    
    class CameraPosition {
        // Stores the x, y and z angles for the cameraPos
        var coords = SCNVector3(x: -10, y: 10, z: 16)
        let radius: Float = 16 // Radius of the sphere in which the camera moves around car
    }
    
    struct SinglePosition { // Stores one set of coordinates of a car at a given time from the start of the lap
        var coords: SCNVector3 // Current coordinate of car
        var timestamp: Double // No. of seconds since the start of the lap
        var interpolated: Bool = false // True if the coord was calculated via interpolation
        
        // Any position will be sorted in chronological order
        static func <(lhs: SinglePosition, rhs: SinglePosition) -> Bool {
            return lhs.timestamp < rhs.timestamp
        }
    }
    
    class CarPositions { // Contains all the positions of a given car for a given lap
        var positions: [SinglePosition] = []
    }
    
    // Non-private attributes will be referred to by LapComparisonView when instantiating SimulScene
    var cameraPos = CameraPosition()
    var actionSequences = [SCNAction]()
    var trackNode = SCNNode()
    var startPosList = [(startPos: SCNVector3, lookAt: SCNVector3)]() // Passed to SimulScene to set start pos of cars and initial lookAt direction
    var driverList = [String]()
    private var allLapData = [Lap]() // Raw laps sorted by lap time
    private var allCarPos = [CarPositions]() // Position data sorted by lap time
    
    private var processor: DataProcessor
    
    init(processor: DataProcessor) {
        self.processor = processor
    }
    
    func load(drivers: [String], laps: [Int]) {
        for i in 0...(drivers.count - 1) {
            let lap = processor.driverDatabase[drivers[i]]?.laps[String(laps[i])]
            if let lap {
                if !lap.PositionData.isEmpty {
                    allLapData.insertSorted(newItem: lap)
                    allCarPos.append(CarPositions())
                    // Legend in LapSimulationView includes driver sName and Lap Number stored in driverList. Sorted by lapTime
                    let drvInfo = (processor.driverInfo.lookup[drivers[i]]?.sName ?? "") + " L" + String(laps[i])
                    driverList.insert(drvInfo, at: allLapData.firstIndex(of: lap) ?? 0)
                } else {
                    return // TODO: Throw error
                }
            } else {
                return // TODO: Throw error
            }
        }
        
        for i in 0...(allLapData.count - 1) {
            getRawPositions(lap: allLapData[i], target: allCarPos[i])
            // TODO: Evaluate need to sync start/end positions
//            if i != 0 {
//                syncStartPoint(target: allCarPos[i])
//                syncEndPoint(target: allCarPos[i])
//            }
            resampleToFrequency(target: allCarPos[i], frequency: 10)
            savitskyGolayFilter(target: allCarPos[i])
            actionSequences.append(generateActionSequence(target: allCarPos[i]))
            startPosList.append((startPos: allCarPos[i].positions[0].coords, lookAt: allCarPos[i].positions[1].coords))
        }
        
        trackNode = SCNPathNode(path: allCarPos[0].positions.map { $0.coords }, width: 12, curvePoints: 32)
        allCarPos = [] // These objects are no longer needed. Deallocating memory
        allLapData = []
    }
    
    private func getRawPositions(lap: Lap, target: CarPositions) {
        /*
         The first position data may not represent the coords of the car the moment it crossed the start finish line due to the low sample rate
         At t = 0, the car should be exactly on the SL line. (First timestamp - Lap start timestamp) is used to offset all timestamps such that
         they are now relative to t = 0 when the car crossed the SL line.
         We interpolate the coords at which the car crossed the start finish line by drawing a line between the first two coords of the car and
         finding the coords when t = 0. The end point is interpolated in a similar fashion using the total lap time
         */
        
        let posData = lap.PositionData
        let delta = posData[0].timestamp - lap.StartTime
        for i in 0...(posData.count - 1) {
            let coords = posData[i].value.components(separatedBy: ",")
            if coords[0] == "OnTrack" { // Kafka also broadcasts OffTrack coords which we can ignore
                // All coords are divided by 10 since F1 provides data that is accurate to 1/10th of a meter.
                let x = (Float(coords[1]) ?? 0) / -10 // - sign is added as Scenekit directions are inverted compared to F1 data
                let y = (Float(coords[3]) ?? 0) / 10 // y and z coords are swapped between F1 live data and SceneKit
                let z = (Float(coords[2]) ?? 0) / 10
                
                target.positions.append(
                    SinglePosition(coords: SCNVector3(x: x, y: y, z: z), timestamp: posData[i].timestamp - posData[0].timestamp + delta)
                )
            }
        }
        
        // Start point is being interpolated from timestamp of lap start
        let startPoint = linearInterpolatePos(prev: target.positions[0], next: target.positions[1], t: 0)
        target.positions.insert(SinglePosition(coords: startPoint, timestamp: 0), at: 0)
        
        // End point is being interpolated from lap time
        let lapTime = convertLapTimeToSeconds(time: lap.LapTime.value)
        let endPoint = linearInterpolatePos(prev: target.positions[target.positions.count - 2], next: target.positions[target.positions.count - 1], t: lapTime)
        target.positions.append(SinglePosition(coords: endPoint, timestamp: Double(lapTime)))
    }
     
    private func syncStartPoint(target: CarPositions) {
        /*
         Lap start time is calculated using the timestamp the car left the pits / timestamp of sector 3 time update of previous lap. Due to delays in the sensors detecting the above, lap start time is not always consistent between laps/cars. As cars are usually travelling >300km/h at the SL line, these small inconsistencies can cause the start points of two cars to be visibly different. Hence, there is a need to sync the start points
         
         The chase cars start point is synced to the lead cars. The closest point to the lead cars start point in the path of the chase car is set as it's start point.
         */
        
        func distance(p1: SCNVector3, p2: SCNVector3) -> Float { // Returns distance between points
            return sqrtf(powf(p1.x - p2.x, 2) + powf(p1.z - p2.z, 2))
        }
        
        let refPoint = allCarPos[0].positions[0].coords // Lead cars start point is used as the reference
        // Point 1 and 2 are the closest two points to the lead cars start point
        var prev = distance(p1: target.positions[0].coords, p2: refPoint)
        var count = 1
        var dist = distance(p1: target.positions[count].coords, p2: refPoint)
        
        while dist < prev {
            prev = dist
            count += 1
            dist = distance(p1: target.positions[count].coords, p2: refPoint)
        }
        
        let point1 = target.positions[count-1]
        let point2 = target.positions[count]
        
        // TODO: Crash can occur if point1 and 2 are the same
        
        /*
         A line is drawn that contains point 1 and 2. The point on the line closest to the lead cars start point is calculated by finding the normal to the line that passes through lead cars start point. This is the new start point of the chase car. The time at which the car passes through this new start point is calculated. All the chase timestamps are offset such that they are relative to the new start point.
         
         The line is assumed to be 2D (x,z axes) for simplicity of calculation
         */
        
        /*
         Edge case (1):
         Gradient of line is undefined: Closest point has the same z coord as refPoint
         Edge case (2):
         Gradient of line is 0: Closest point has the same x coord as refPoint
         */
        var x: Float
        var z: Float
        var deltaT: Float
        
        if (point1.coords.x - point2.coords.x) == 0 { // Edge case (1)
            x = point1.coords.x
            z = refPoint.z
            
            let numerator = point1.timestamp - point2.timestamp
            let m = Float(numerator) / (point1.coords.z - point2.coords.z)
            let c = Float(point1.timestamp) - (m * point1.coords.z)
            deltaT = (m*z) + c // Time of new start point relative to old start point
            
        } else {
            if (point1.coords.z - point2.coords.z) == 0 { // Edge case (2)
                x = refPoint.x
                z = point1.coords.z
            } else {
                let gradient = (point1.coords.z - point2.coords.z) / (point1.coords.x - point2.coords.x)
                let zIntrcpt = point1.coords.z - (gradient * point1.coords.x)
                
                let gradientNormal = -(1/gradient)
                let zIntrcptNormal = refPoint.z - (gradientNormal * refPoint.x) // The normal which passes through lead start point is calculated
                
                /*
                 The intersection between line and normal is used to calculate new start point
                 z = m₁x + c₁ --> (line)
                 z = m₂x + c₂ --> (normal)
                 At insersection point:
                 m₁x + c₁ = m₂x + c₂
                 (m₁ - m₂)x = c₂ - c₁
                 x = (c₂ - c₁) / (m₁ - m₂)
                 */
                x = (zIntrcpt - zIntrcptNormal) / (gradientNormal - gradient)
                z = (gradient * x) + zIntrcpt
            }
            
            let numerator = point1.timestamp - point2.timestamp
            let m = Float(numerator) / (point1.coords.x - point2.coords.x)
            let c = Float(point1.timestamp) - (m * point1.coords.x)
            deltaT = (m*x) + c // Time of new start point relative to old start point
        }
        
        // Adjust timestamps to be relative to new startPoint. Any positions before new startPoint is discarded
        var removeFirst = -1
        for i in 0...(target.positions.count - 1) {
            target.positions[i].timestamp -= Double(deltaT) // Offset all timestamps to be relative to new start point
            if target.positions[i].timestamp < 0 {
                removeFirst = i
            }
        }
        
        if removeFirst != -1 { // Remove positions that were before the new start point
            target.positions.removeFirst(removeFirst+1)
        }
        
        let startPoint = SCNVector3(x: x, y: target.positions[0].coords.y, z: z)
        target.positions.insert(SinglePosition(coords: startPoint, timestamp: 0), at: 0)
    }
    
    private func syncEndPoint(target: CarPositions) {
        /*
         This function is used to sync a slower cars lap time to match the fastest lap time. All position data after fastest lap time has elapsed is removed. The position of the car at the point where fastest lap time has elapsed is also interpolated as the last position of the car
         */
        let lapTime = Double(convertLapTimeToSeconds(time: allLapData[0].LapTime.value))
        var count = target.positions.count - 1
        var delta = target.positions[count].timestamp - target.positions[0].timestamp
        
        while delta > lapTime {
            count -= 1
            delta = target.positions[count].timestamp - target.positions[0].timestamp
        }
        
        target.positions.removeLast(target.positions.count - count - 1) // Removing extra positions
        
        let endPoint = linearInterpolatePos(prev: target.positions[target.positions.count - 2], next: target.positions[target.positions.count - 1], t: Float(lapTime))
        target.positions.append(SinglePosition(coords: endPoint, timestamp: lapTime))
    }
    
    private func resampleToReference(reference: CarPositions, target: CarPositions) {
        /*
         All timestamps in reference will be added to target, if not already present.
         
         Resampling ensures that both cars will have the same number of position data points. There is no loss of accuracy when resampling as linear interpolation is done between non-interpolated data to calculate missing data points. This would have been done anyway since the SCNAction.move(duration:) is a linear animation. Loss of accuracy comes during the smoothing of data.
         
         The resampled data ensures that both cars will have SCNAction.move() being called in parallel and for the same number of times, preventing processing delays from adding up and diverging the gap between the cars.
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
        fillMissing(target: target)
    }
    
    private func resampleToFrequency(target: CarPositions, frequency: Double) {
        /*
         Resamples data to the specified frequency (Hz). First and last data points are kept intact. Refer to
         resampleToReference() for explanation on why resampling is necessary
        */
        
        let lastTimestamp = target.positions.last?.timestamp ?? 0
        let delta = 1 / frequency
        var curTime = delta
        
        while curTime < lastTimestamp {
            let item = SinglePosition(coords: SCNVector3(), timestamp: curTime, interpolated: true)
            let index = target.positions.insertionIndexOf(elem: item) {$0 < $1}
            target.positions.insert(item, at: index)
            curTime += delta
        }
        
        fillMissing(target: target)
        
        // Preserve first and last data points. All other non-interpolated data is removed
        // This does not cause any loss in accuracy as resampled frequency is higher than source frequency
        for i in stride(from: target.positions.count - 2, to: 0, by: -1) {
            if target.positions[i].interpolated == false {
                target.positions.remove(at: i)
            }
        }
    }
    
    private func fillMissing(target: CarPositions) {
        /*
         Any data point that is marked with interpolated == true will have it's coordinate calculated via linear interpolation between
         the previous coordinate and the next non-interpolated coordinate.
        */
        for i in 0...(target.positions.count - 1) {
            if target.positions[i].interpolated == true {
                var j = i
                while j < target.positions.count { // Finding next non-interpolated data point
                    if target.positions[j].interpolated == false {
                        target.positions[i].coords = linearInterpolatePos(prev: target.positions[i-1], next: target.positions[j], t: Float(target.positions[i].timestamp))
                        break
                    } else {
                        j += 1
                    }
                }
            }
        }
    }
        
    private func linearInterpolatePos(prev: SinglePosition, next: SinglePosition, t: Float) -> SCNVector3 {
        /*
         t: Float is the timestamp for which the unknown coord should be calculated. The linear equation of a line formed by
         (time1, x1/y1/z1) and (time2, x2/y2/z2) is calculated using subtraction method of solving simult. eqns. t is subsitituted in to find unknown coord
         
         m is gradient, c is y-intercept
         t₁ = mx₁ + c --> (1)
         t₂ = mx₂ + c --> (2)
         (1) - (2)
         m = (t₁ - t₂) / (x₁ - x₂)
         c = (t₁ - mx₁)
        */
        
        func solveEqn(prev: Float, next: Float, prevTime: Double, nextTime: Double) -> Float {
            let numerator = Float(prevTime - nextTime)
            if (prev - next).isNearlyEqual(to: 0) {
                return prev
            }
            let m = numerator / (prev - next)
            let c = Float(prevTime) - (m * prev)
            return (t - c) / m
        }
        
        let x = solveEqn(prev: prev.coords.x, next: next.coords.x, prevTime: prev.timestamp, nextTime: next.timestamp)
        let y = solveEqn(prev: prev.coords.y, next: next.coords.y, prevTime: prev.timestamp, nextTime: next.timestamp)
        let z = solveEqn(prev: prev.coords.z, next: next.coords.z, prevTime: prev.timestamp, nextTime: next.timestamp)
        
        return SCNVector3(x: x, y: y, z: z)
    }
    
    private func smoothConvolve(target: CarPositions) {
        var xSmooth: [Float] = []
        var ySmooth: [Float] = []
        var zSmooth: [Float] = []

        for i in 0...(target.positions.count - 1) {
            xSmooth.append(target.positions[i].coords.x)
            ySmooth.append(target.positions[i].coords.y)
            zSmooth.append(target.positions[i].coords.z)
        }
        
        // Padding to ensure output is same size as input
        xSmooth = [Float](repeating: xSmooth[0], count: 10) + xSmooth
        ySmooth = [Float](repeating: ySmooth[0], count: 10) + ySmooth
        zSmooth = [Float](repeating: zSmooth[0], count: 10) + zSmooth
        
        // TODO: Use center weighted convolution coefficients to give greater priority to actual value
        // E.g) [0.1, 0.2, 0.4, 0.2, 0.1]
        // Compare to savitsky golay filter
        xSmooth = vDSP.convolve(xSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        ySmooth = vDSP.convolve(ySmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        zSmooth = vDSP.convolve(zSmooth, withKernel: [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1])
        
        for i in 0...(xSmooth.count - 1) {
            target.positions[i].coords.x = xSmooth[i]
            target.positions[i].coords.y = ySmooth[i]
            target.positions[i].coords.z = zSmooth[i]
        }
    }
    
    private func savitskyGolayFilter(target: CarPositions) {
        /*
         A Savitsky-Golay filter is applied to the resampled position data to smooth out noise in the data. The filter
         is applied within a window length of 20 (~1s before & after current point is used to calculate interpolated point) and a
         polyorder of 2 (quadratic).
         
         https://en.wikipedia.org/wiki/Savitzky%E2%80%93Golay_filter
         For equally spaced data points, an analytical solution to the least-squares equations can be found, in the form of the
         convolution coefficients.
         
         NOTE: Can only be used if data is equally spaced. Call resampleToFrequency() before calling this function.
        */
        
        var xSmooth: [Float] = []
        var ySmooth: [Float] = []
        var zSmooth: [Float] = []

        for i in 0...(target.positions.count - 1) {
            xSmooth.append(target.positions[i].coords.x)
            ySmooth.append(target.positions[i].coords.y)
            zSmooth.append(target.positions[i].coords.z)
        }

        // Wrap style padding to ensure output is same size as input
        xSmooth = Array(xSmooth[(xSmooth.count-9)...(xSmooth.count-1)]) + xSmooth + Array(xSmooth[0...10])
        ySmooth = Array(ySmooth[(ySmooth.count-9)...(ySmooth.count-1)]) + ySmooth + Array(ySmooth[0...10])
        zSmooth = Array(zSmooth[(zSmooth.count-9)...(zSmooth.count-1)]) + zSmooth + Array(zSmooth[0...10])
        
        // Savitsky Golay coefficients calculated using window length = 20, polyorder = 2
        let kernel: [Float] = [-0.05795455,-0.02386364,0.00643939,0.03295455,0.05568182,0.07462121,0.08977273,0.10113636,0.10871212,0.1125,0.1125,0.10871212,0.10113636,0.08977273,0.07462121,0.05568182,0.03295455,0.00643939,-0.02386364,-0.05795455]
        
        xSmooth = vDSP.convolve(xSmooth, withKernel: kernel)
        ySmooth = vDSP.convolve(ySmooth, withKernel: kernel)
        zSmooth = vDSP.convolve(zSmooth, withKernel: kernel)
        
        for i in 0...(xSmooth.count - 1) {
            target.positions[i].coords.x = xSmooth[i]
            target.positions[i].coords.y = ySmooth[i]
            target.positions[i].coords.z = zSmooth[i]
        }
    }
    
    private func generateActionSequence(target: CarPositions) -> SCNAction {
        var seq: [SCNAction] = []
        for i in 1...(target.positions.count - 1) {
            /*
             These placeholder vars are needed to avoid the lookWithDurationAction block from using reference-type values of x,y,z from
             the target instance at the time the action is called, instead of the values when the block is instantiated.
            */
            let x = target.positions[i].coords.x
            let y = target.positions[i].coords.y
            let z = target.positions[i].coords.z
            let dur = target.positions[i].timestamp - target.positions[i-1].timestamp // No. of seconds taken for animation
            
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
