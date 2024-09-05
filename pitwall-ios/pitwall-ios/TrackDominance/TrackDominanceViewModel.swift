//
//  TrackDominanceViewModel.swift
//  pitwall-ios
//
//  Created by Robin on 4/8/23.
//

import Foundation

class TrackDominanceViewModel {
    
    // TODO: Set limit of 5 cars and series identifiers using sorted lap time
    
    private struct SpeedPosData: Comparable {
        // SpeedPosData is used as a temporary container that stores both position data and speed data extracted from CarData
        struct SinglePosition: Comparable {
            let x: Float
            let y: Float
            let timestamp: Double
            
            static func <(lhs: SinglePosition, rhs: SinglePosition) -> Bool {
                return lhs.timestamp < rhs.timestamp
            }
        }

        struct SingleSpeed: Comparable {
            let s: Int
            let timestamp: Double
            
            static func <(lhs: SingleSpeed, rhs: SingleSpeed) -> Bool {
                return lhs.timestamp < rhs.timestamp
            }
        }
        
        let rNum: String
        let speeds: [SingleSpeed]
        let pos: [SinglePosition]
        let lapTime: Float // Allows for sorting by fastest lap time
        
        static func <(lhs: SpeedPosData, rhs: SpeedPosData) -> Bool {
            return lhs.lapTime < rhs.lapTime
        }
    }
    
    var processedData = [(x: Float, y: Float, rNum: String, series: Int)]() // Final data that is passed to TrackDominanceView
    private var rawData = [SpeedPosData]() // Used to hold interim processing data
    
    private var processor: DataProcessor
    
    init(processor: DataProcessor) {
        self.processor = processor
    }
    
    func load(drivers: [String], laps: [Int]) {
        for i in 0...(drivers.count - 1) {
            let posData = processor.driverDatabase[drivers[i]]?.laps[String(laps[i])]?.PositionData
            let carData = processor.driverDatabase[drivers[i]]?.laps[String(laps[i])]?.CarData
            let lapTime = convertLapTimeToSeconds(time: processor.driverDatabase[drivers[i]]?.laps[String(laps[i])]?.LapTime.value ?? "")
            
            if let posData, let carData {
                if posData.isEmpty || carData.isEmpty {
                    return // TODO: Handle error
                }
                
                var speeds = [SpeedPosData.SingleSpeed]()
                var pos = [SpeedPosData.SinglePosition]()
                let startT = posData[0].timestamp
                
                for i in 0...(posData.count - 1) {
                    let coords = posData[i].value.components(separatedBy: ",")
                    if coords[0] == "OnTrack" { // Kafka also broadcasts OffTrack coords which we can ignore
                        // All coords are divided by 10 since F1 provides data that is accurate to 1/10th of a meter.
                        let x = (Float(coords[1]) ?? 0) / 10
                        let y = (Float(coords[2]) ?? 0) / 10
                        pos.append(SpeedPosData.SinglePosition(x: x, y: y, timestamp: posData[i].timestamp - startT))
                    }
                }
                    
                for i in 0...(carData.count - 1) {
                    let speed = carData[i].value.components(separatedBy: ",")[1]
                    speeds.append(SpeedPosData.SingleSpeed(s: Int(speed) ?? 0, timestamp: carData[i].timestamp - startT))
                }
                let rNum = (processor.driverInfo.lookup[drivers[i]]?.sName ?? "") + " L" + String(laps[i])
                rawData.insertSorted(newItem: SpeedPosData(rNum: rNum, speeds: speeds, pos: pos, lapTime: lapTime))
            } else {
                return // TODO: Handle error
            }
        }
        extractFastestSections(resolution: 50)
        rawData = [] // rawData is no longer needed. Deallocating memory
    }
    
    var maxY = -Float.infinity // The min/max X & Y values are recorded to scale the track to the edges in Swift Charts
    var minY = Float.infinity
    var maxX = -Float.infinity
    var minX = Float.infinity
    
    private func extractFastestSections(resolution: Float) {
        /*
         The posData for the car with the fastest lap time is used as the reference for which the track is drawn. The function iterates through each position of the lead car, and finds the speed of all other cars at a position that is closest to reference position.
         
         The closest position is found by first conducting a binary search of the timestamp at which the reference position was set. Since all lap times are within the same order of magnitude, this gives a good start point for the search. We then search both directions in time till we find the exact closest position. The timestamp of this position is used to interpolate the speed of the car.
         
         The resolution parameter controls the length of the track on which the speed of the cars is averaged. The track is split into sections that are roughly equal to the resolution. Each section has it's own series, to ensure that they are treated as line segments in Swift Charts, each with their own color to denote which car was fastest. The last point in series 1 is also the first point in eries 2. This ensures that all the line segments are joined to form a continous track.
        */
        func distance(p1: SpeedPosData.SinglePosition, p2: SpeedPosData.SinglePosition) -> Float { // Returns distance between p1 & p2
            return sqrtf(powf((p1.x - p2.x), 2) - powf((p1.y - p2.y), 2))
        }
        
        var series = 0
        var start = 0
        while start <= (rawData[0].pos.count - 1)  {
            /*
             The speeds array contains the cumulative speed for a car over a section of the track. The index of a car's speed in the array is the same as the index of the car's data in the rawData array.
            */
            var speeds = [Int](repeating: 0, count: rawData.count)
            var end = start
            
            /*
             start to end is the index range which represents a section of track that is ~= resolution. For every point in this range, the speeds of all cars is found using findClosestTime() and interpolateSpeed(). The
            */
            for i in start...(rawData[0].pos.count - 1) {
                maxX = rawData[0].pos[i].x > maxX ? rawData[0].pos[i].x : maxX // Find minX/Y and maxX/Y values
                minX = rawData[0].pos[i].x < minX ? rawData[0].pos[i].x : minX
                maxY = rawData[0].pos[i].y > maxY ? rawData[0].pos[i].y : maxY
                minY = rawData[0].pos[i].y < minY ? rawData[0].pos[i].y : minY
                
                for j in 0...(rawData.count - 1) {
                    if j == 0 { // No need to interpolate position for reference fastest car
                        speeds[j] += interpolateSpeed(data: rawData[0], timestamp: rawData[0].pos[i].timestamp)
                    } else {
                        let t = findClosestTime(data: rawData[j], refPoint: rawData[0].pos[i]) // Find timestamp at which car was closest to ref position
                        speeds[j] += interpolateSpeed(data: rawData[j], timestamp: t)
                    }
                }
                
                if distance(p1: rawData[0].pos[i], p2: rawData[0].pos[start]) >= resolution { // Split track into sections of resolution length
                    end = i
                    break
                }
            }
            
            /*
             For a given section of the track, the car with the highest cumulative speed had the highest average speed. Since the index of a car in the speeds array is the same as the index in the rawData array, the index of the max() element in the speeds array will point us to the racing number of the car that had the highest average speed
            */
            let maxS = speeds.max() ?? 0
            let rNum = rawData[((speeds.firstIndex(of: maxS) ?? 0) % rawData.count)].rNum
            
            for k in start...end {
                /*
                 Since the TrackDominanceView only shows which car was fastest at a given section and not the speed, the final
                 processed data only contains x/y coords, the racing number of the fastest car and a series identifier
                */
                processedData.append((x: rawData[0].pos[k].x, y: rawData[0].pos[k].y, rNum: rNum, series: series))
                series += 1
                processedData.append((x: rawData[0].pos[k].x, y: rawData[0].pos[k].y, rNum: rNum, series: series))
            }
            
            start = end + 1
        }
    }
    
    private func findClosestTime(data: SpeedPosData, refPoint: SpeedPosData.SinglePosition) -> Double {
        func distance(p: SpeedPosData.SinglePosition) -> Float { // Returns distance between p and refPoint
            return sqrtf(powf((p.x - refPoint.x), 2) - powf((p.y - refPoint.y), 2))
        }
        
        let startIndex = max(0, min(data.pos.count - 1, data.pos.binarySearch(elem: refPoint))) // Finds position with the closest timestamp to be used as start point of search
        
        // Search forward & backward in time as car could be ahead/behind the reference car at any given point before lap end
        var prevDist = distance(p: data.pos[startIndex])
        var curIndex = startIndex
        while curIndex > 0 { // Searching backward in time
            let curDist = distance(p: data.pos[curIndex])
            if curDist <= prevDist {
                curIndex -= 1
                prevDist = curDist
            } else {break}
        }

        let backwardIndex = curIndex // Index of closest position when searching backward in time
        
        prevDist = distance(p: data.pos[startIndex])
        curIndex = startIndex
        while curIndex < (data.pos.count - 1) { // Searching forward in time
            let curDist = distance(p: data.pos[curIndex])
            if curDist <= prevDist {
                curIndex += 1
                prevDist = curDist
            } else {break}
        } // curIndex is the index of the closest position when searching forward in time
        
        var point1: SpeedPosData.SinglePosition
        var point2: SpeedPosData.SinglePosition
        // Check if closest position was backward/forward in time
        if distance(p: data.pos[backwardIndex]) < distance(p: data.pos[curIndex]) { // Closest position was backward in time
            if backwardIndex == 0 { // Boundary checking
                point1 = data.pos[backwardIndex]
                point2 = data.pos[backwardIndex + 1]
            } else {
                point1 = data.pos[backwardIndex - 1]
                point2 = data.pos[backwardIndex]
            }
        } else { // Closest position was forward in time
            if curIndex == (data.pos.count - 1) { // Boundary checking
                point1 = data.pos[curIndex - 1]
                point2 = data.pos[curIndex]
            } else {
                point1 = data.pos[curIndex]
                point2 = data.pos[curIndex + 1]
            }
        }
        
        /*
         Point 1 and 2 are the closest two data points in cars path to the refPoint. refPoint lies somewhere in the space between points 1 & 2.
         Similar to syncStartPoint in LapSimulationViewModel, a line is drawn that contains point 1 and 2. The point on the line closest to the
         refPoint is calculated by finding the normal to the line that passes through refPoint. The timestamp of this new point is later used
         to calculate the speed of the car.
        */
        
        // TODO: Better handling in case where gradient is undefined / 0
        if ((point1.y - point2.y) == 0) || ((point1.x - point2.x) == 0) {
            return point1.timestamp
        }
        
        let gradient = (point1.y - point2.y) / (point1.x - point2.x)
        let yIntrcpt = point1.y - (gradient * point1.x)
        
        let gradientNormal = -(1/gradient)
        let yIntrcptNormal = refPoint.y - (gradientNormal * refPoint.x)
        
        let x = (yIntrcpt - yIntrcptNormal) / (gradientNormal - gradient)
        
        var m: Float
        var c: Float
        let numerator = point1.timestamp - point2.timestamp
        m = Float(numerator) / (point1.x - point2.x)
        c = Float(point1.timestamp) - (m * point1.x)
        return Double((m*x) + c) // Time of closest point in cars path to refPoint
    }
    
    private func interpolateSpeed(data: SpeedPosData, timestamp: Double) -> Int {
        let startIndex = max(1, min(data.speeds.count - 2, data.speeds.binarySearch(elem: SpeedPosData.SingleSpeed(s: 0, timestamp: timestamp))))
        var prev: SpeedPosData.SingleSpeed
        var next: SpeedPosData.SingleSpeed
                
        if data.speeds[startIndex].timestamp < timestamp {
            prev = data.speeds[startIndex]
            next = data.speeds[startIndex+1]
        } else {
            prev = data.speeds[startIndex-1]
            next = data.speeds[startIndex]
        }
                
        if (prev.s - next.s) == 0 {
            return prev.s
        } else {
            let m = Float(prev.timestamp - next.timestamp) / Float(prev.s - next.s)
            let c = Float(prev.timestamp) - (m * Float(prev.s))
            return Int((Float(timestamp) - c) / m)
        }
        
    }
}
