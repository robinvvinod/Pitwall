//
//  SpeedTraceView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI
import Charts

struct SpeedTraceView: View {
    
    var driver: [String]
    var lap: [String]
    private var carData: [[Double]]
    
    var body: some View {
        Chart {
            ForEach(carData, id: \.self) { item in
                LineMark(x: .value("Distance", item[1]), y: .value("Speed", item[0]))
            }
        }
    }

}
