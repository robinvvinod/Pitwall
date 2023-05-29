//
//  GapOrIntervalView.swift
//  pitwall-ios
//
//  Created by Robin on 24/5/23.
//

import SwiftUI
import Charts

struct GapOrIntervalView: View {
    
    let driver: String
    let type: String // Set to "GAP" or "INT" representing GapToLeader or IntervalToPositionAhead respectively
    @EnvironmentObject var processor: DataProcessor
    @State private var intervalsArray = [(lap: Int, gap: Float)]()
    
    @State private var selectedIndex: Int?
    @State private var selectedPoint: String?
    @State private var curLap: Int = 0
    
    var body: some View {
        VStack {
            HStack {
                if let selectedPoint, let selectedIndex {
                    Text("Lap: \(selectedIndex + 1)")
                    Text("Gap: \(selectedPoint)s")
                } else {
                    Text("Lap: -")
                    Text("Gap: -")
                }
            }
            gapOrIntervalView
        }.padding()
    }
    
    var gapOrIntervalView: some View {
        Chart {
            if intervalsArray.count <= 3 {
                ForEach(0..<intervalsArray.count, id: \.self) { index in
                    if let selectedIndex, selectedIndex == index {
                        RuleMark(x: .value("Lap", intervalsArray[index].lap))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        PointMark(x: .value("Lap", intervalsArray[index].lap), y: .value("Gap", intervalsArray[index].gap))
                            .foregroundStyle(Color.orange)
                    }
                    
                    BarMark (
                        x: .value("Lap", intervalsArray[index].lap),
                        y: .value("Gap", intervalsArray[index].gap),
                        width: 25
                    )
                    .foregroundStyle(Color.blue)
                    .annotation(position: .overlay, alignment: .center) {
                        Text("\(String(format: "%.3f", intervalsArray[index].gap))s")
                            .rotationEffect(.degrees(-90))
                            .font(.caption)
                            .fixedSize()
                    }
                }
            } else {
                ForEach(0..<intervalsArray.count, id: \.self) { index in
                    if let selectedIndex, selectedIndex == index {
                        RuleMark(x: .value("Lap", intervalsArray[index].lap))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        PointMark(x: .value("Lap", intervalsArray[index].lap), y: .value("Gap", intervalsArray[index].gap))
                            .foregroundStyle(Color.orange)
                    }
                    
                    LineMark (
                        x: .value("Lap", intervalsArray[index].lap),
                        y: .value("Gap", intervalsArray[index].gap)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
        }
        .onReceive(processor.objectWillChange) {
            intervalsArray = getGapOrInterval(driver: driver)
        }
        .onAppear {
            intervalsArray = getGapOrInterval(driver: driver)
        }
        .chartOverlay { chart in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let currentX = value.location.x - geometry[chart.plotAreaFrame].origin.x
                                // Check that drag gesture did not go beyond chart boundaries
                                guard currentX >= 0, currentX < chart.plotAreaSize.width else {return}
                                // Convert screen x position to chart coordinate space
                                guard let index = chart.value(atX: currentX, as: Int.self) else {return}
                                selectedIndex = index
                                if (index >= 0) && (index < intervalsArray.count) {
                                    selectedPoint = String(intervalsArray[index].gap)
                                } else {
                                    selectedPoint = nil
                                }
                            }
                    )
                    .onTapGesture { location in
                        let currentX = location.x - geometry[chart.plotAreaFrame].origin.x
                        // Check that drag gesture did not go beyond chart boundaries
                        guard currentX >= 0, currentX < chart.plotAreaSize.width else {return}
                        // Convert screen x position to chart coordinate space
                        guard let index = chart.value(atX: currentX, as: Int.self) else {return}
                        selectedIndex = index
                        if (index >= 0) && (index < intervalsArray.count) {
                            selectedPoint = String(intervalsArray[index].gap)
                        } else {
                            selectedPoint = nil
                        }
                    }
            }
        }
        .chartXAxisLabel("Lap")
        .chartYAxisLabel("Gap (s)")
        .chartXScale(domain: 0...curLap)
    }
    
    func getGapOrInterval(driver: String) -> [(lap: Int, gap: Float)] {
        var intervalsArray = [(lap: Int, gap: Float)]()
        guard let driverObject = processor.driverDatabase[driver] else {return intervalsArray}
        if driverObject.CurrentLap == 0 {
            return intervalsArray
        }
        for lap in 1..<(driverObject.CurrentLap) {
            if type == "GAP" {
                let gap = driverObject.laps[String(lap)]?.GapToLeader.last ?? (0, "")
                intervalsArray.append((lap: lap, gap: gap.value))
            } else {
                let gap = driverObject.laps[String(lap)]?.IntervalToPositionAhead.last ?? (0, "")
                intervalsArray.append((lap: lap, gap: gap.value))
            }
        }
        curLap = driverObject.CurrentLap
        return intervalsArray
    }
}
