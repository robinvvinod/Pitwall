//
//  Telemetry.swift
//  pitwall-ios
//
//  Created by Robin on 18/5/23.
//

import Foundation

func integrate(pt1: [Double], pt2: [Double]) -> Double {
    // eq: [x,y]
    // x coord of eq2 should be larger than x coord of eq1
    
    var triangleArea: Double = 0
    var rectangularArea: Double = 0
    let y1 = pt1[1] / 3.6   // Convert km/h to m/s
    let y2 = pt2[1] / 3.6
    let x1 = pt1[0]
    let x2 = pt2[0]
    
    triangleArea = 0.5 * abs(y2 - y1) * (x2-x1)
    if y1 > y2 {
        rectangularArea = (x2 - x1) * y2
    } else {
        rectangularArea = (x2 - x1) * y1
    }
    return triangleArea + rectangularArea
}

func addDistance(CarData: [(value: String, timestamp: Double)]) -> [(speed: Double, distance: Double)] {
    var returnArr = [(speed: Double, distance: Double)]()
    
    for (i, item) in CarData.enumerated() {
        let timestamp = item.timestamp
        let speed = Double(item.value.components(separatedBy: ",")[1]) ?? 0
        
        if i == 0 { // Distance travelled is 0 on first sample
            returnArr.append((speed: speed, distance: 0))
        } else {
            let prev = CarData[i-1]
            let timestampPrev = prev.timestamp
            let speedPrev = Double(prev.value.components(separatedBy: ",")[1]) ?? 0
            let distance = integrate(pt1: [timestampPrev, speedPrev], pt2: [timestamp, speed]) + (returnArr.last?.distance ?? 0)
            returnArr.append((speed: speed, distance: distance))
        }
    }
    return returnArr
}
