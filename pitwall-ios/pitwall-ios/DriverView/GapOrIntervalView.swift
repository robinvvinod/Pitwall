//
//  GapOrIntervalView.swift
//  pitwall-ios
//
//  Created by Robin on 24/5/23.
//

import SwiftUI
import Charts

struct GapOrIntervalView: View {
    
    @StateObject var viewModel: GapOrIntervalViewModel
    @EnvironmentObject private var processor: DataProcessor
    
    @State private var selectedIndex: Int?
    @State private var selectedPoint: String?
    
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
            if viewModel.intervalsArray.count <= 3 {
                ForEach(0..<viewModel.intervalsArray.count, id: \.self) { index in
                    if let selectedIndex, selectedIndex == index {
                        RuleMark(x: .value("Lap", viewModel.intervalsArray[index].lap))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        PointMark(x: .value("Lap", viewModel.intervalsArray[index].lap), y: .value("Gap", viewModel.intervalsArray[index].gap))
                            .foregroundStyle(Color.orange)
                    }
                    
                    BarMark (
                        x: .value("Lap", viewModel.intervalsArray[index].lap),
                        y: .value("Gap", viewModel.intervalsArray[index].gap),
                        width: 25
                    )
                    .foregroundStyle(Color.blue)
                    .annotation(position: .overlay, alignment: .center) {
                        Text("\(String(format: "%.3f", viewModel.intervalsArray[index].gap))s")
                            .rotationEffect(.degrees(-90))
                            .font(.caption)
                            .fixedSize()
                    }
                }
            } else {
                ForEach(0..<viewModel.intervalsArray.count, id: \.self) { index in
                    if let selectedIndex, selectedIndex == index {
                        RuleMark(x: .value("Lap", viewModel.intervalsArray[index].lap))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        PointMark(x: .value("Lap", viewModel.intervalsArray[index].lap), y: .value("Gap", viewModel.intervalsArray[index].gap))
                            .foregroundStyle(Color.orange)
                    }
                    
                    LineMark (
                        x: .value("Lap", viewModel.intervalsArray[index].lap),
                        y: .value("Gap", viewModel.intervalsArray[index].gap)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
        }
        .chartOverlay { chart in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let currentX = value.location.x - geometry[chart.plotAreaFrame].origin.x
                                // Check that drag gesture did not go beyond chart boundaries
                                guard currentX >= 0, currentX < chart.plotAreaSize.width else {return}
                                // Convert screen x position to chart coordinate space
                                guard let index = chart.value(atX: currentX, as: Int.self) else {return}
                                selectedIndex = index
                                if (index >= 0) && (index < viewModel.intervalsArray.count) {
                                    selectedPoint = String(viewModel.intervalsArray[index].gap)
                                } else {
                                    selectedPoint = nil
                                }
                            }
                    )
            }
        }
        .chartXAxisLabel("Lap")
        .chartYAxisLabel("Gap (s)")
        .chartXScale(domain: 0...viewModel.curLap)
    }
}
