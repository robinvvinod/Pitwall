//
//  TrackDominanceView.swift
//  pitwall-ios
//
//  Created by Robin on 22/7/23.
//

import SwiftUI
import Charts

class TrackDominanceViewModel {
    
    struct SpeedPosData: Comparable {
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
        let lapTime: Float
        
        static func <(lhs: SpeedPosData, rhs: SpeedPosData) -> Bool {
            return lhs.lapTime < rhs.lapTime
        }
    }
    
    private var rawData = [SpeedPosData]()
    var processedData = [(x: Float, y: Float, s: Int, rNum: String, series: Int)]()
    
    func load(processor: DataProcessor, drivers: [String], laps: [Int]) {
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
                        let x = (Float(coords[1]) ?? 0) / 10 // - sign is added as Scenekit directions are inverted compared to F1 data
                        let y = (Float(coords[2]) ?? 0) / 10 // y and z coords are swapped between F1 live data and SceneKit
                        pos.append(SpeedPosData.SinglePosition(x: x, y: y, timestamp: posData[i].timestamp - startT))
                    }
                }
                    
                for i in 0...(carData.count - 1) {
                    let speed = carData[i].value.components(separatedBy: ",")[1] // Safety check requried?
                    speeds.append(SpeedPosData.SingleSpeed(s: Int(speed) ?? 0, timestamp: carData[i].timestamp - startT))
                }
                
                rawData.insertSorted(newItem: SpeedPosData(rNum: drivers[i], speeds: speeds, pos: pos, lapTime: lapTime))
            } else {
                return // TODO: Handle error
            }
        }
        seperateFastest()
    }
    
    private func seperateFastest() {
        var series: Int = 0
        for i in 0...(rawData[0].pos.count - 1) {
            var speed = interpolateSpeed(data: rawData[0], timestamp: rawData[0].pos[i].timestamp)
            var rNum = rawData[0].rNum
            for j in 1...(rawData.count - 1) {
                let t = findClosestTime(data: rawData[j], refPoint: rawData[0].pos[i])
                let s = interpolateSpeed(data: rawData[j], timestamp: t)
                if s > speed {
                    speed = s
                    rNum = rawData[j].rNum
                }
            }
            if i % 5 == 0 {
                series += 1
            }
            processedData.append((x: rawData[0].pos[i].x, y: rawData[0].pos[i].y, s: speed, rNum: rNum, series: series))
        }
    }
    
    private func findClosestTime(data: SpeedPosData, refPoint: SpeedPosData.SinglePosition) -> Double {
        func distance(p: SpeedPosData.SinglePosition) -> Float { // Returns distance between p and refPoint
            return sqrtf(powf((p.x - refPoint.x), 2) - powf((p.y - refPoint.y), 2))
        }
        
        let startIndex = max(0, min(data.pos.count - 1, data.pos.binarySearch(elem: refPoint))) // Finds position with the closest timestamp to be used as start point of search
        // Search forward & backward in time as car could be ahead/behind the reference car at any given point before lap end
        
        var refDist = distance(p: data.pos[startIndex])
        var curIndex = startIndex
        while curIndex > 0 { // Searching backward in time
            let curDist = distance(p: data.pos[curIndex])
            if curDist <= refDist {
                curIndex -= 1
                refDist = curDist
            } else {break}
        }

        let backwardIndex = curIndex
        
        refDist = distance(p: data.pos[startIndex])
        curIndex = startIndex
        while curIndex < (data.pos.count - 1) { // Searching forward in time
            let curDist = distance(p: data.pos[curIndex])
            if curDist <= refDist {
                curIndex += 1
                refDist = curDist
            } else {break}
        }
        
        var point1: SpeedPosData.SinglePosition
        var point2: SpeedPosData.SinglePosition
        if distance(p: data.pos[backwardIndex]) < distance(p: data.pos[curIndex]) {
            if backwardIndex == 0 {
                point1 = data.pos[backwardIndex]
                point2 = data.pos[backwardIndex + 1]
            } else {
                point1 = data.pos[backwardIndex - 1]
                point2 = data.pos[backwardIndex]
            }
        } else {
            if curIndex == (data.pos.count - 1) {
                point1 = data.pos[curIndex - 1]
                point2 = data.pos[curIndex]
            } else {
                point1 = data.pos[curIndex]
                point2 = data.pos[curIndex + 1]
            }
        }
        
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
        
        let startIndex = max(0, min(data.speeds.count - 2, data.speeds.binarySearch(elem: SpeedPosData.SingleSpeed(s: 0, timestamp: timestamp))))
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

struct TrackDominanceView: View {
    
    @EnvironmentObject private var processor: DataProcessor
    @State private var viewModel = TrackDominanceViewModel()
    @State private var loaded = false
    
    var body: some View {
        VStack {
            if loaded {
                Chart {
                    ForEach(0...viewModel.processedData.count - 1, id: \.self) { i in
                        LineMark(x: .value("x", viewModel.processedData[i].x), y: .value("y", viewModel.processedData[i].y), series: .value("series", viewModel.processedData[i].series))
                            .foregroundStyle(by: .value("rNum", viewModel.processedData[i].rNum))
                    }
                }
            }
        }.onAppear {
            viewModel.load(processor: processor, drivers: ["1", "14"], laps: [30,30])
            print(viewModel.processedData)
            loaded = true
        }
    }
}
