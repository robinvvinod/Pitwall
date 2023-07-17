//
//  SpeedTraceView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI
import Charts

struct SpeedTraceData: Hashable {
    let id = UUID()
    let speeds: [Double]
    let distances: [Double]
}

class SpeedTraceViewModel: ObservableObject {
    var drivers: [String]?
    var laps: [Int]?
    var processor: DataProcessor?
    var speedData = [SpeedTraceData]()
    var lastDist: Double = 0
    
    @Published var upperBound: Double = 0
    @Published var lowerBound: Double = 0
    
    func load(processor: DataProcessor, drivers: [String], laps: [Int]) {
        self.processor = processor
        self.drivers = drivers
        self.laps = laps
        
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
            var speeds = [Double]()
            var distances = [Double]()
            for j in 0...(distData.count - 1) {
                speeds.append(distData[j].speed)
                distances.append(distData[j].distance)
            }
            speedData.append(SpeedTraceData(speeds: speeds, distances: distances))
        }
        
        for driver in speedData {
            if (driver.distances.last ?? 1) > lastDist {
                lastDist = driver.distances.last ?? 1
            }
        }
        
        upperBound = lastDist
    }
}

struct SpeedTraceView: View {
    
    @StateObject var viewModel: SpeedTraceViewModel
    @State private var selectedIndex: Double?
    @State private var selectedPoint1: Int?
    @State private var selectedPoint2: Int?
    
    var body: some View {
        VStack {
            if let selectedPoint1, let selectedPoint2 {
                HStack {
                    Spacer()
                    Text("\(Int(viewModel.speedData[0].speeds[selectedPoint1]))km/h")
                    Spacer()
                    Text("\(Int(viewModel.speedData[1].speeds[selectedPoint2]))km/h")
                    Spacer()
                }
            }
            chartView
        }
        
    }
        
    var chartView: some View {
        Chart {
            ForEach(0..<viewModel.speedData.count, id: \.self) { i in
                let indvData = viewModel.speedData[i]
                ForEach(0..<indvData.speeds.count, id: \.self) { j in
                    LineMark(x: .value("Distance", indvData.distances[j]), y: .value("Speed", indvData.speeds[j]), series: .value("", i))
                        .foregroundStyle(i % 2 == 0 ? Color.blue : Color.orange)
                }
            }
            
            if let selectedIndex {
                RuleMark(x: .value("Distance", selectedIndex))
                    .foregroundStyle(Color.gray.opacity(0.8))
            }
        }
        .chartXScale(domain: viewModel.lowerBound...viewModel.upperBound)
        .chartOverlay { chart in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if (viewModel.lowerBound != 0) && (viewModel.upperBound != viewModel.lastDist) {
                                    return
                                }
                                let currentX = value.location.x - geometry[chart.plotAreaFrame].origin.x
                                // Check that drag gesture did not go beyond chart boundaries
                                guard currentX >= 0, currentX < chart.plotAreaSize.width else {return}
                                // Convert screen x position to chart coordinate space
                                guard let index = chart.value(atX: currentX, as: Double.self) else {return}
                                selectedIndex = index
                                selectedPoint1 = max(0, min(viewModel.speedData[0].distances.binarySearch(elem: index), viewModel.speedData[0].distances.count - 1))
                                selectedPoint2 = max(0, min(viewModel.speedData[1].distances.binarySearch(elem: index), viewModel.speedData[1].distances.count - 1))
                            }
                            .simultaneously(with: zoom.simultaneously(with: pan))
                    )
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
                viewModel.upperBound = min(viewModel.upperBound, viewModel.lastDist)
                
                let midpoint = (viewModel.upperBound + viewModel.lowerBound) / 2
                selectedIndex = midpoint
                selectedPoint1 = max(0, min(viewModel.speedData[0].distances.binarySearch(elem: midpoint), viewModel.speedData[0].distances.count - 1))
                selectedPoint2 = max(0, min(viewModel.speedData[1].distances.binarySearch(elem: midpoint), viewModel.speedData[1].distances.count - 1))
                
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
                if (viewModel.upperBound == viewModel.lastDist) && (viewModel.lowerBound == 0) {return}
                
                let gap = viewModel.upperBound - viewModel.lowerBound
                let distance = (value.translation.width - prevX) * (gap / 500)
                                
                viewModel.upperBound = min(viewModel.upperBound + distance, viewModel.lastDist + (gap / 2))
                viewModel.lowerBound = max(viewModel.lowerBound + distance, 0 - (gap / 2))
                
                if (viewModel.upperBound == viewModel.lastDist + (gap / 2)) {
                    viewModel.lowerBound = viewModel.lastDist - (gap / 2)
                } else if (viewModel.lowerBound == 0 - (gap / 2)) {
                    viewModel.upperBound = 0 + (gap / 2)
                }
                
                let midpoint = (viewModel.upperBound + viewModel.lowerBound) / 2
                selectedIndex = midpoint
                selectedPoint1 = max(0, min(viewModel.speedData[0].distances.binarySearch(elem: midpoint), viewModel.speedData[0].distances.count - 1))
                selectedPoint2 = max(0, min(viewModel.speedData[1].distances.binarySearch(elem: midpoint), viewModel.speedData[1].distances.count - 1))
                
                prevX = value.translation.width
            }
            .onEnded { value in
                prevX = 0
            }
    }
    
}
