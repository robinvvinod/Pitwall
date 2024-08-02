//
//  HeadToHeadViewModel.swift
//  pitwall-ios
//
//  Created by Robin on 1/8/24.
//

import Foundation

class HeadToHeadViewModel: ObservableObject {
    
    private var processor: DataProcessor
    
    init(processor: DataProcessor) {
        self.processor = processor
    }
    
    func load(drivers: [String], laps: [Int]) -> (SpeedTraceViewModel, TrackDominanceViewModel, LapSimulationViewModel) {
        let speedTraceVM = SpeedTraceViewModel(processor: processor)
        let trackDomincanceVM = TrackDominanceViewModel(processor: processor)
        let lapComparisonVM = LapSimulationViewModel(processor: processor)
        
        speedTraceVM.load(drivers: drivers, laps: laps)
        trackDomincanceVM.load(drivers: drivers, laps: laps)
        lapComparisonVM.load(drivers: drivers, laps: laps)
        
        return (speedTraceVM, trackDomincanceVM, lapComparisonVM)
    }
}
