//
//  SpeedTraceViewModel.swift
//  pitwall-ios
//
//  Created by Robin on 4/8/23.
//

import Foundation

class SpeedTraceViewModel: ObservableObject {
    
    struct SpeedTraceData: Hashable {
        let id: String
        let speeds: [Int]
        let distances: [Double]
        let lapTime: Float
    }
    
    var speedData = [SpeedTraceData]()
    var lastVal: Double = 0
    @Published var upperBound: Double = 0
    @Published var lowerBound: Double = 0
    
    func load(processor: DataProcessor, drivers: [String], laps: [Int]) {
        
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
            
            let distData = addDistance(CarData: data)
            var speeds = [Int]()
            var distances = [Double]()
            for j in 0...(distData.count - 1) {
                speeds.append(distData[j].speed)
                distances.append(distData[j].distance)
            }
            speedData.append(SpeedTraceData(id: driver, speeds: speeds, distances: distances, lapTime: lapTime))
            
        }
        
        for driver in speedData {
            if (driver.distances.last ?? 1) > lastVal {
                lastVal = driver.distances.last ?? 1
            }
        }
        
        speedData.sort {$0.lapTime < $1.lapTime}
        DispatchQueue.main.async {
            self.upperBound = self.lastVal
        }
    }
    
    func getSpeed(speedData: SpeedTraceData, distance: Double) -> Int {
        let index = speedData.distances.binarySearch(elem: distance)
        if speedData.distances[index] == distance {
            return Int(speedData.speeds[index])
        } else {
            if (index == 0) || (index == speedData.distances.count - 1) {
                return Int(speedData.speeds[index])
            }
            
            var prev: (s: Int, d: Double)
            var next: (s: Int, d: Double)
            if speedData.distances[index] > distance {
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
