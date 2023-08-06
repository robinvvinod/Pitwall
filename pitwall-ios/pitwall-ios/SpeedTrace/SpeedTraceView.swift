//
//  SpeedTraceView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI
import Charts

struct SpeedTraceView: View {
    
    @EnvironmentObject var processor: DataProcessor
    @StateObject var viewModel: SpeedTraceViewModel
    @State private var selectedIndex: Double? // Used to hold x-val of selected point
    
    var body: some View {
        chartView
    }
        
    var chartView: some View {
        Chart {
            ForEach(0..<viewModel.speedData.count, id: \.self) { i in
                let indvData = viewModel.speedData[i]
//                let drvName = processor.driverInfo.lookup[indvData.id]?.sName ?? ""
                ForEach(0..<indvData.speeds.count, id: \.self) { j in
                    LineMark(x: .value("Distance", indvData.distances[j]), y: .value("Speed", indvData.speeds[j]), series: .value("", i))
                        .foregroundStyle(by: .value("rNum", indvData.id))
                }
            }
            // If selectedIndex is not nil, show a rule mark at the corresponding x-val (distance) in chart
            if let selectedIndex {
                RuleMark(x: .value("Distance", selectedIndex))
                    .foregroundStyle(Color.gray.opacity(0.8))
            }
        }
        .chartXAxisLabel("Distance")
        .chartYAxisLabel("Speed (km/h)")
        .chartXScale(domain: viewModel.lowerBound...viewModel.upperBound) // View is refreshed when these values change
        .chartOverlay { chart in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                /*
                                 This gesture is only used when the chart is fully zoomed out. Current touch x location is converted to chart
                                 index. The corresponding x-val at this index is set as selectedIndex. Since selectedIndex is a @State var,
                                 view is refreshed to show rule mark at selected location.
                                */
                                if (viewModel.lowerBound != 0) && (viewModel.upperBound != viewModel.lastVal) {
                                    return
                                }
                                let currentX = value.location.x - geometry[chart.plotAreaFrame].origin.x
                                // Check that drag gesture did not go beyond chart boundaries
                                guard currentX >= 0, currentX < chart.plotAreaSize.width else {return}
                                // Convert screen x position to chart coordinate space
                                guard let index = chart.value(atX: currentX, as: Double.self) else {return}
                                selectedIndex = index
                            }
                            .simultaneously(with: zoom.simultaneously(with: pan))
                    )
            }
        }
        .chartBackground { chart in
            GeometryReader { geometry in
                // This is used to show a lollipop with the y-vals of the selected point in the chart
                if let selectedIndex {
                    let pos = (chart.position(forX: selectedIndex) ?? 0) + geometry[chart.plotAreaFrame].origin.x // x-pos of selected point
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.8))
                        
                        VStack(spacing: 0) {
                            ForEach(0..<viewModel.speedData.count, id: \.self) { i in
                                // Interpolate speed at selected distance
                                let point = viewModel.getSpeed(speedData: viewModel.speedData[i], distance: selectedIndex)
                                let name = processor.driverInfo.lookup[viewModel.speedData[i].id]?.sName ?? ""
                                Text("\(name): \(point)km/h")
                                    .padding(.vertical, 2)
                                    .font(.caption)
                            }
                        }
                    }
                    .position(x: pos, y: 0)
                    .frame(width: 100, height: 25)
                }
            }
        }
    }
    
    @State private var prevScale: CGFloat = 0 // Used to detect direction changes within one gesture
    private let modifier: Double = 50 // Scale by which zoom is done (in meters)
    var zoom: some Gesture {
        return MagnificationGesture()
            .onChanged { scale in
                if scale > prevScale { // Zooming in
                    viewModel.lowerBound += modifier
                    viewModel.upperBound -= modifier
                } else { // Zooming out
                    viewModel.lowerBound -= modifier
                    viewModel.upperBound += modifier
                }
                
                if (viewModel.upperBound - viewModel.lowerBound) < modifier { // Max zoom is set as (upperBound - lowerBound = modifier)
                    viewModel.upperBound += modifier
                    viewModel.lowerBound -= modifier
                }
                
                viewModel.lowerBound = max(0, viewModel.lowerBound) // Bounds checking
                viewModel.upperBound = min(viewModel.upperBound, viewModel.lastVal)
                
                selectedIndex = (viewModel.upperBound + viewModel.lowerBound) / 2 // Selected point is always the mid value when chart is zoomed
                prevScale = scale
        }
            .onEnded { scale in
                prevScale = scale
            }
    }
    
    @State private var prevX: CGFloat = 0 // Used to detect direction changes within one gesture
    var pan: some Gesture {
        return DragGesture()
            .onChanged { value in
                // This gesture is unused if chart is fully zoomed out
                if (viewModel.upperBound == viewModel.lastVal) && (viewModel.lowerBound == 0) {return}
                
                let gap = viewModel.upperBound - viewModel.lowerBound
                /*
                 Distance to move in pan is scaled according to how zoomed in the chart is. If chart is more zoomed out, distance is
                 proportionally larger as well. This allows for fine/coarse control in panning depending on zoom level
                */
                let distance = (value.translation.width - prevX) * (gap / 500)
                                
                /*
                 Max value for upper bound during pan is set as (viewModel.lastVal + (gap/2)). This is because selected index is
                 set as the mid point point between upper and lower bounds. Having the upper bound increase by gap/2 allows the selectedIndex
                 to coincide exactly with the last value when panning all the way to the boundary. This ensures consistent panning behaviour
                 in the middle and edges of the chart. Same is true for the lower bound.
                */
                viewModel.upperBound = min(viewModel.upperBound + distance, viewModel.lastVal + (gap / 2))
                viewModel.lowerBound = max(viewModel.lowerBound + distance, 0 - (gap / 2))
                
                if (viewModel.upperBound == viewModel.lastVal + (gap / 2)) {
                    viewModel.lowerBound = viewModel.lastVal - (gap / 2)
                } else if (viewModel.lowerBound == 0 - (gap / 2)) {
                    viewModel.upperBound = 0 + (gap / 2)
                }
                
                selectedIndex = (viewModel.upperBound + viewModel.lowerBound) / 2 // Mid point
                prevX = value.translation.width
            }
            .onEnded { value in
                prevX = 0
            }
    }
    
}
