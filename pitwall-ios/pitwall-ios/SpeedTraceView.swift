//
//  SpeedTraceView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI
import Charts


class SpeedTraceViewModel: ObservableObject {
    
    struct SpeedTraceData: Hashable {
        let id: String
        let speeds: [Int]
        let distances: [Double]
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
            speedData.append(SpeedTraceData(id: driver, speeds: speeds, distances: distances))
        }
        
        for driver in speedData {
            if (driver.distances.last ?? 1) > lastVal {
                lastVal = driver.distances.last ?? 1
            }
        }
        
        upperBound = lastVal // TODO: Change this on main thread
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

struct SpeedTraceView: View {
    
    @EnvironmentObject var processor: DataProcessor
    @StateObject var viewModel: SpeedTraceViewModel
    @State private var selectedIndex: Double?
    
    var body: some View {
        chartView
    }
        
    var chartView: some View {
        Chart {
            ForEach(0..<viewModel.speedData.count, id: \.self) { i in
                let indvData = viewModel.speedData[i]
                let drvName = processor.driverInfo.lookup[indvData.id]?.sName ?? ""
                ForEach(0..<indvData.speeds.count, id: \.self) { j in
                    LineMark(x: .value("Distance", indvData.distances[j]), y: .value("Speed", indvData.speeds[j]), series: .value("", i))
                        .foregroundStyle(by: .value("Racing Number", drvName))
                }
            }
            
            if let selectedIndex {
                RuleMark(x: .value("Distance", selectedIndex))
                    .foregroundStyle(Color.gray.opacity(0.8))
            }
        }
        .chartXAxisLabel("Distance")
        .chartYAxisLabel("Speed (km/h)")
        .chartXScale(domain: viewModel.lowerBound...viewModel.upperBound)
        .chartOverlay { chart in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
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
                if let selectedIndex {
                    let pos = (chart.position(forX: selectedIndex) ?? 0) + geometry[chart.plotAreaFrame].origin.x
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.8))
                        
                        VStack(spacing: 0) {
                            ForEach(0..<viewModel.speedData.count, id: \.self) { i in
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
    
    @State private var prevScale: CGFloat = 0
    private let modifier: Double = 50
    var zoom: some Gesture {
        return MagnificationGesture()
            .onChanged { scale in
                if scale > prevScale {
                    viewModel.lowerBound += modifier
                    viewModel.upperBound -= modifier
                } else {
                    viewModel.lowerBound -= modifier
                    viewModel.upperBound += modifier
                }
                
                if (viewModel.upperBound - viewModel.lowerBound) < modifier {
                    viewModel.upperBound += modifier
                    viewModel.lowerBound -= modifier
                }
                
                viewModel.lowerBound = max(0, viewModel.lowerBound)
                viewModel.upperBound = min(viewModel.upperBound, viewModel.lastVal)
                
                selectedIndex = (viewModel.upperBound + viewModel.lowerBound) / 2
                prevScale = scale
        }
            .onEnded { scale in
                prevScale = scale
            }
    }
    
    @State private var prevX: CGFloat = 0
    var pan: some Gesture {
        return DragGesture()
            .onChanged { value in
                if (viewModel.upperBound == viewModel.lastVal) && (viewModel.lowerBound == 0) {return}
                
                let gap = viewModel.upperBound - viewModel.lowerBound
                let distance = (value.translation.width - prevX) * (gap / 500)
                                
                viewModel.upperBound = min(viewModel.upperBound + distance, viewModel.lastVal + (gap / 2))
                viewModel.lowerBound = max(viewModel.lowerBound + distance, 0 - (gap / 2))
                
                if (viewModel.upperBound == viewModel.lastVal + (gap / 2)) {
                    viewModel.lowerBound = viewModel.lastVal - (gap / 2)
                } else if (viewModel.lowerBound == 0 - (gap / 2)) {
                    viewModel.upperBound = 0 + (gap / 2)
                }
                
                selectedIndex = (viewModel.upperBound + viewModel.lowerBound) / 2
                prevX = value.translation.width
            }
            .onEnded { value in
                prevX = 0
            }
    }
    
}
