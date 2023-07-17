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

class LapSimulationViewModel {
    
    var cameraPos = CameraPosition()
    var car1Seq = SCNAction()
    var car2Seq = SCNAction()
    var trackNode = SCNNode()
    var startPos = (p1: SCNVector3(), l1: SCNVector3(), p2: SCNVector3(), l2: SCNVector3())
    private var car1Pos = CarPositions()
    private var car2Pos = CarPositions()
    private var processor: DataProcessor?
    
    func load(processor: DataProcessor, selDriver: (car1: (driver: String, lap: Int), car2: (driver: String, lap: Int))) {
        self.processor = processor
        let lap1 = processor.driverDatabase[selDriver.car1.driver]?.laps[String(selDriver.car1.lap)] // Get lap object
        let lap2 = processor.driverDatabase[selDriver.car2.driver]?.laps[String(selDriver.car2.lap)]
        
        if let lap1, let lap2 {
            if (lap1.PositionData.isEmpty) || (lap2.PositionData.isEmpty) {
                return
                // TODO: Throw error
            }
            
            // Faster lap is set as car1 and is the reference from which start/end point is set & track is generated
            if convertLapTimeToSeconds(time: lap1.LapTime.value) < convertLapTimeToSeconds(time: lap2.LapTime.value) {
                loadLapData(lead: lap1, chase: lap2)
            } else {
                loadLapData(lead: lap2, chase: lap1)
            }
            
            car1Seq = generateActionSequence(carPos: car1Pos)
            car2Seq = generateActionSequence(carPos: car2Pos)
            
            startPos = (p1: car1Pos.positions[0].coords, l1: car1Pos.positions[1].coords, p2: car2Pos.positions[0].coords, l2: car2Pos.positions[1].coords)
            
            trackNode = SCNPathNode(path: car1Pos.positions.map { $0.coords }, width: 12, curvePoints: 32)
            car1Pos = CarPositions() // carPos is no longer needed, deallocating memory
            car2Pos = CarPositions()
        }
    }
    
    private func loadLapData(lead: Lap, chase: Lap) {
        getRawPositions(lap: lead, carPos: car1Pos)
        getRawPositions(lap: chase, carPos: car2Pos)
        
        syncStartPoints()
        syncEndPoint(lap: lead, carPos: car1Pos)
        syncEndPoint(lap: chase, carPos: car2Pos)
        
        resampleToFrequency(carPos: car1Pos, frequency: 10)
        resampleToFrequency(carPos: car2Pos, frequency: 10)
        
        savitskyGolayFilter(carPos: car1Pos)
        savitskyGolayFilter(carPos: car2Pos)
        
        calculateDurations(carPos: car1Pos)
        calculateDurations(carPos: car2Pos)
    }
    
    private func getRawPositions(lap: Lap, carPos: CarPositions) {
        /*
         The first position data may not represent the coords of the car the moment it crossed the start finish line due to the low sample rate
         At t = 0, the car should be exactly on the SL line. (First timestamp - Lap start timestamp) is used to offset all timestamps such that
         they are now relative to t = 0 when the car crossed the SL line.
         We interpolate the coords at which the car crossed the start finish line by drawing a line between the first two coords of the car and
         finding the coords when t = 0
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
                
                carPos.positions.append(
                    SinglePosition(coords: SCNVector3(x: x, y: y, z: z), timestamp: posData[i].timestamp - posData[0].timestamp + delta)
                )
            }
        }
        
        let startPoint = linearInterpolate(prev: carPos.positions[0], next: carPos.positions[1], t: 0)
        carPos.positions.insert(SinglePosition(coords: startPoint, timestamp: 0), at: 0)
    }
    
    private func syncStartPoints() {
        /*
         Lap start time is calculated using the timestamp the car left the pits / timestamp of sector 3 time of previous lap
         Due to delays in the sensors detecting the above, lap start time is not always consistent between laps/cars
         As cars are usually travelling >300km/h at the SL line, these small inconsistencies can cause the start points of two
         cars to be visibly different. Hence, there is a need to sync the start points
         
         The chase cars start point is synced to the lead cars. The closest point to the lead cars start point in the path of the chase
         car is set as it's start point.
        */
        let lead = car1Pos
        let chase = car2Pos
        
        func distance(v: SCNVector3) -> Float { // Returns distance of point from origin
            return sqrtf(powf(v.x, 2) + powf(v.z, 2))
        }
        
        let refPoint = lead.positions[0].coords // Lead cars start point is used as the reference
        // Point 1 and 2 are the closest two points to the lead cars start point
        var point1: SinglePosition
        var point2: SinglePosition
        
        let dist1 = distance(v: refPoint)
        var dist2 = distance(v: chase.positions[0].coords)
        
        
        if dist2 > dist1 { // Chase cars start point is after lead start point
            point1 = chase.positions[0]
            point2 = chase.positions[1]
        } else { // Chase cars start point is before lead start point
            var count = 0
            while dist2 < dist1 {
                count += 1
                dist2 = distance(v: chase.positions[count].coords)
            }
            point1 = chase.positions[count-1]
            point2 = chase.positions[count]
        }
        
        /*
         A line is drawn that contains point 1 and 2. The point on the line closest to the lead cars start point is calculated by finding
         the normal to the line that passes through lead cars start point. This is the new start point of the chase car. The time at which
         the car passes through this new start point is calculated. All the chase timestamps are offset such that they are relative to the
         new start point.
         
         The line is assumed to be 2D (x,z axes) for simplicity of calculation
        */
        
        // TODO: Handle case where gradient is undefined
        let gradient = (point1.coords.z - point2.coords.z) / (point1.coords.x - point2.coords.x)
        let yIntrcpt = point1.coords.z - (gradient * point1.coords.x)
        
        let gradientNormal = -(1/gradient)
        let yIntrcptNormal = refPoint.z - (gradientNormal * refPoint.x) // The normal which passes through lead start point is calculated
        
        /*
         The intersection between line and normal is used to calculate new start point
         z = m₁x + c₁ --> (line)
         z = m₂x + c₂ --> (normal)
         At insersection point:
         m₁x + c₁ = m₂x + c₂
         (m₁ - m₂)x = c₂ - c₁
         x = (c₂ - c₁) / (m₁ - m₂)
        */
        let x = (yIntrcpt - yIntrcptNormal) / (gradientNormal - gradient)
        let z = (gradient * x) + yIntrcpt
        
        var t: Float
        var m: Float
        var c: Float
        let numerator = point1.timestamp - point2.timestamp
        m = Float(numerator) / (point1.coords.x - point2.coords.x)
        c = Float(point1.timestamp) - (m * point1.coords.x)
        t = (m*x) + c // Time of new start point relative to old start point
        
        for i in 0...(chase.positions.count - 1) {
            chase.positions[i].timestamp -= Double(t) // Offset all timestamps to be relative to new start point
        }
        
        let startPoint = SCNVector3(x: x, y: chase.positions[0].coords.y, z: z)
        chase.positions.insert(SinglePosition(coords: startPoint, timestamp: 0), at: 0)
    }
    
    private func syncEndPoint(lap: Lap, carPos: CarPositions) {
        // Setting end point timestamp to be equal to total lap time
        let lapTime = Double(convertLapTimeToSeconds(time: lap.LapTime.value))
        var count = carPos.positions.count - 1
        var delta = carPos.positions[count].timestamp - carPos.positions[0].timestamp
        /*
         In the backend, the lap start timestamps are used to determine which lap a given position data
         belongs to. Due to possible delays in receiving this new lap timestamp, it is possible that that the
         position data contains values for the next lap which was wrongly attributed to the current lap. Hence it is possible for
         (last timestamp - first timestamp) > (laptime). We can remove any position data for which this statement is true
        */
        while delta > lapTime {
            carPos.positions.remove(at: count)
            count -= 1
            delta = carPos.positions[count].timestamp - carPos.positions[0].timestamp
        }
        
        // Similar technique to syncStartPoints() is used to find closest point in cars path to the start point.
        // Car should be at this new point at timestamp = laptime
        
        let refPoint = carPos.positions[0].coords
        let point1 = carPos.positions[count].coords
        let point2 = carPos.positions[count-1].coords
        
        let gradient = (point1.z - point2.z) / (point1.x - point2.x)
        let yIntrcpt = point1.z - (gradient * point1.x)
        
        let gradientNormal = -(1/gradient)
        let yIntrcptNormal = refPoint.z - (gradientNormal * refPoint.x)
        
        let x = (yIntrcpt - yIntrcptNormal) / (gradientNormal - gradient)
        let z = (gradient * x) + yIntrcpt
        
        let lastPoint = SCNVector3(x: x, y: point1.y, z: z)
        carPos.positions.append(
            SinglePosition(coords: lastPoint, timestamp: lapTime)
        )
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
    
    private func resampleToFrequency(carPos: CarPositions, frequency: Double) {
        /*
         Resamples data to the specified frequency (Hz). First and last data points are kept intact. Refer to
         resampleToReference() for explanation on why resampling is necessary
        */
        
        let lastTimestamp = carPos.positions.last?.timestamp ?? 0
        var curTime = 1 / frequency
        
        while curTime < lastTimestamp {
            let item = SinglePosition(coords: SCNVector3(), timestamp: curTime, interpolated: true)
            let index = carPos.positions.insertionIndexOf(elem: item) {$0 < $1}
            carPos.positions.insert(item, at: index)
            curTime += 0.1
        }
        
        fillMissing(carPos: carPos)
        
        // Preserve first and last data points. All other non-interpolated data is removed
        for i in stride(from: carPos.positions.count - 2, to: 1, by: -1) {
            if carPos.positions[i].interpolated == false {
                carPos.positions.remove(at: i)
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
        xSmooth = [Float](repeating: xSmooth[0], count: 10) + xSmooth
        ySmooth = [Float](repeating: ySmooth[0], count: 10) + ySmooth
        zSmooth = [Float](repeating: zSmooth[0], count: 10) + zSmooth
        
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

        for i in 0...(carPos.positions.count - 1) {
            xSmooth.append(carPos.positions[i].coords.x)
            ySmooth.append(carPos.positions[i].coords.y)
            zSmooth.append(carPos.positions[i].coords.z)
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
