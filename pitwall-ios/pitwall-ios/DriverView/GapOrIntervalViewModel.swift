//
//  GapOrIntervalViewModel.swift
//  pitwall-ios
//
//  Created by Robin on 5/9/24.
//

import Foundation

class GapOrIntervalViewModel: ObservableObject {
    
    @Published var driver: String
    @Published var intervalsArray = [(lap: Int, gap: Float)]()
    @Published var curLap: Int = 0
    let type: String // Set to "GAP" or "INT" representing GapToLeader or IntervalToPositionAhead respectively

    private var processor: DataProcessor
    
    init(processor: DataProcessor, driver: String, type: String) {
        self.driver = driver
        self.processor = processor
        self.type = type
    }
    
    func getGapOrInterval() {
        intervalsArray = [(lap: Int, gap: Float)]()
        guard let driverObject = processor.driverDatabase[driver] else {return}
        if driverObject.CurrentLap == 0 {return}
        for lap in 1..<(driverObject.CurrentLap) {
            if type == "GAP" {
                let gap = driverObject.laps[String(lap)]?.GapToLeader.last ?? (0, 0)
                intervalsArray.append((lap: lap, gap: gap.value))
            } else {
                let gap = driverObject.laps[String(lap)]?.IntervalToPositionAhead.last ?? (0, 0)
                intervalsArray.append((lap: lap, gap: gap.value))
            }
        }
        curLap = driverObject.CurrentLap
    }
}
