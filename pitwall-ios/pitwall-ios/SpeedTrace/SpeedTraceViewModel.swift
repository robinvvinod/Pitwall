//
//  SpeedTraceViewModel.swift
//  pitwall-ios
//
//  Created by Robin on 4/8/23.
//

import Foundation

class SpeedTraceViewModel: ObservableObject {
    
    struct SpeedTraceData: Comparable {
        let id: String
        let speeds: [Int]
        let distances: [Double]
        let lapTime: Float // Used to sort by fastest laptimes
        
        static func <(lhs: SpeedTraceData, rhs: SpeedTraceData) -> Bool {
            return lhs.lapTime < rhs.lapTime
        }
    }
    
    var speedData = [SpeedTraceData]() // Final data that gets passed to SpeedTraceView
    var lastVal: Double = 0 // Set to the furthest distance. Used to make sure upperbound does not overflow data bounds
    @Published var upperBound: Double = 0 // Used to control bounds of sliding window of chart when zooming/panning
    @Published var lowerBound: Double = 0
    
    private var processor: DataProcessor
    
    init(processor: DataProcessor) {
        self.processor = processor
    }
    
    func load(drivers: [String], laps: [Int]) {
        // Populates speedData array which is passed to SpeedTraceView to display chart
        for i in 0...(drivers.count - 1) {
            let driver = drivers[i]
            let lap = laps[i]
            
            let data = processor.driverDatabase[driver]?.laps[String(lap)]?.CarData
            let lapTime = convertLapTimeToSeconds(time: processor.driverDatabase[driver]?.laps[String(lap)]?.LapTime.value ?? "")
            // TODO: Check for empty carData
            guard let data = data else {
                // TODO: Throw error
                return
            }
            
            let distData = addDistance(CarData: data) // Converts (speed, timestamp) to (speed, distance)
            var speeds = [Int]()
            var distances = [Double]()
            for j in 0...(distData.count - 1) {
                speeds.append(distData[j].speed)
                distances.append(distData[j].distance)
            }
            let rNum = (processor.driverInfo.lookup[driver]?.sName ?? "") + " L" + String(lap)
            speedData.insertSorted(newItem: SpeedTraceData(id: rNum, speeds: speeds, distances: distances, lapTime: lapTime))
            
            if (distances.last ?? 1) > lastVal { // Setting furthest distance among all drivers
                lastVal = distances.last ?? 1
            }
        }
        
        DispatchQueue.main.async { // Changes to @Published values must be done in main thread
            self.upperBound = self.lastVal
        }
    }
    
    func getSpeed(speedData: SpeedTraceData, distance: Double) -> Int {
        /*
         Returns interpolated speed data for any given distance. Used to determine speed when panning through chart since
         not all distances may have a corresponding speed data point.
         
         Finds the index of the closest existing distance using a linear search, then does a linear interpolation using the prev/next
         value to calculate speed at any given distance.
        */
        let index = speedData.distances.binarySearch(elem: distance)
        if speedData.distances[index] == distance { // No interpolation needed, exact data point is available
            return Int(speedData.speeds[index])
        } else {
            if (index == 0) || (index == speedData.distances.count - 1) {
                return Int(speedData.speeds[index]) // Make sure distance is within bounds of data else, return closest boundary val
            }
            
            var prev: (s: Int, d: Double)
            var next: (s: Int, d: Double)
            if speedData.distances[index] > distance { // Select point such that unknown distance lies between prev & next
                prev = (s: speedData.speeds[index-1], d: speedData.distances[index-1])
                next = (s: speedData.speeds[index], d: speedData.distances[index])
            } else {
                prev = (s: speedData.speeds[index], d: speedData.distances[index])
                next = (s: speedData.speeds[index+1], d: speedData.distances[index+1])
            }
            
            let m = Double(prev.s - next.s) / (prev.d - next.d)
            let c = Double(prev.s) - (m * prev.d)
            return Int((distance * m) + c)
        }
    }
}
