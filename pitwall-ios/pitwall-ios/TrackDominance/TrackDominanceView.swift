//
//  TrackDominanceView.swift
//  pitwall-ios
//
//  Created by Robin on 22/7/23.
//

import SwiftUI
import Charts

struct TrackDominanceView: View {
    
    let viewModel: TrackDominanceViewModel
    var body: some View {
        VStack {
            Chart {
                ForEach(0...viewModel.processedData.count - 1, id: \.self) { i in
                    LineMark(x: .value("x", viewModel.processedData[i].x), y: .value("y", viewModel.processedData[i].y), series: .value("series", viewModel.processedData[i].series))
                        .foregroundStyle(by: .value("rNum", viewModel.processedData[i].rNum))
                }
            }
            .chartXScale(domain: viewModel.minX-20...viewModel.maxX+20)
            .chartYScale(domain: viewModel.minY-20...viewModel.maxY+20)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}
