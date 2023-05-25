//
//  GapToPositionAheadView.swift
//  pitwall-ios
//
//  Created by Robin on 24/5/23.
//

import SwiftUI
import Charts

struct GapToPositionAheadView: View {
    
    @EnvironmentObject var processor: DataProcessor
    @State private var gapsArray = [(lap: Int, gap: Float)]()
    let driver: String
    
    @State private var selectedIndex: Int?
    @State private var selectedPoint: String?
    
    var body: some View {
        ZStack {
            gapToPositionAheadView
            Text("\(selectedPoint ?? "")")
        }
    }
    
    var gapToPositionAheadView: some View {
        Chart {
            ForEach(0..<gapsArray.count, id: \.self) { index in
                
                if let selectedIndex, selectedIndex == index {
//                    RectangleMark(
//                        x: .value("Index", index),
//                        yStart: .value("Value", 0),
//                        yEnd: .value("Value", gapsArray[index].gap),
//                        width: 16
//                    )
//                    .opacity(0.4)
                    
                }
                
                LineMark (
                    x: .value("Lap", gapsArray[index].lap),
                    y: .value("Gap", gapsArray[index].gap)
                )
            }
        }.onAppear {
            gapsArray = getGapToPositionAhead(driver: driver)
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
                                if index <= gapsArray.count - 1 {
                                    selectedPoint = String(gapsArray[index].gap)
                                }
                            }
                            .onEnded { _ in
                                selectedIndex = nil
                                selectedPoint = nil
                            }
                    )
            }
        }
    }
    
    func getGapToPositionAhead(driver: String) -> [(lap: Int, gap: Float)] {
        var gapsArray = [(lap: Int, gap: Float)]()
        let driverObject = processor.driverDatabase[driver]
        for lap in 1..<(driverObject?.CurrentLap ?? 0) {
            let gap = driverObject?.laps[String(lap)]?.GapToLeader.last ?? (0, "")
            gapsArray.append((lap: lap, gap: gap.value))
        }
        return gapsArray
    }
}

struct GapToPositionAheadView_Previews: PreviewProvider {
    static var previews: some View {
        GapToPositionAheadView(driver: "14")
    }
}
