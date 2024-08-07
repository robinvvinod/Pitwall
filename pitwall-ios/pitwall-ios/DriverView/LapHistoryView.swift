//
//  LapHistoryView.swift
//  pitwall-ios
//
//  Created by Robin on 27/5/23.
//

import SwiftUI

struct LapHistoryView: View {
    
    let driver: String
    @EnvironmentObject var processor: DataProcessor
    
    var body: some View {
        if processor.driverDatabase[driver]?.CurrentLap != 0 {
            HStack(alignment: .top, spacing: 0) {
                lapNumberView
                ScrollView(.horizontal, showsIndicators: false) {
                    historyView
                }
            }
        } else {
            HStack {
                Spacer()
                Text("Driver has yet to complete a full lap.")
                    .font(.caption)
                Spacer()
            }
        }
    }
    
    var lapNumberView: some View {
        VStack(spacing: 0) {
            // Set column heading
            Text("Lap")
                .padding(8)
                .font(.headline)
                .foregroundStyle(Color.black)
            
            let driverObject = processor.driverDatabase[driver]
            if let driverObject {
                ForEach(1...driverObject.CurrentLap, id: \.self) { j in
                    HStack {
                        Text(String(j))
                            .foregroundStyle(Color.white)
                            .padding(8)
                            .foregroundStyle(Color.white)
                    }
                    .frame(maxWidth: .infinity)
                    .background(j % 2 == 0 ? Color(UIColor.lightGray) : Color(UIColor.darkGray)) // Alternate row colours
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    var historyView: some View {
        // HStack contains a VStack column for each item in headers
        HStack(spacing: 0) {
            let headers = ["Lap Time", "Gap", "Tyre", "Sector 1", "Sector 2", "Sector 3", "ST1", "ST2", "ST3"]
            ForEach(0..<headers.count, id: \.self) { i in
                VStack(spacing: 0) {
                    // Set heading for column
                    Text("\(headers[i])")
                        .padding(8)
                        .font(.headline)
                    
                    let driverObject = processor.driverDatabase[driver]
                    if let driverObject {
                        ForEach(1...driverObject.CurrentLap, id: \.self) { j in
                            HStack { // HStack in case any column has more than 1 data point inside. E.g) Tyre
                                let lap = driverObject.laps[String(j)] ?? Lap(TyreType: ("", 0))
                                switch headers[i] {
                                case "Lap Time":
                                    let driverFastestLap = driverObject.FastestLapTime
                                    let curLap = convertLapTimeToSeconds(time: lap.LapTime.value)
                                    
                                    Text("\(lap.LapTime.value)")
                                        .foregroundStyle(Color.white)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(curLap.isNearlyEqual(to: driverFastestLap) ? curLap.isNearlyEqual(to: processor.sessionDatabase.FastestLapTime) ? Color.purple : Color.green : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                    
                                case "Gap":
                                    if j != 0 {
                                        let gap = String(format: "%.3f", (convertLapTimeToSeconds(time: lap.LapTime.value) - processor.sessionDatabase.FastestLapTime))
                                        Text("+\(gap)")
                                            .padding(8)
                                            .foregroundStyle(Color.white)
                                    } else { // First driver has no gap to fastest lap attribute
                                        Text("+0.000")
                                            .padding(8)
                                            .foregroundStyle(Color.white)
                                    }
                                    
                                case "Tyre":
                                    Text("\(lap.TyreType.value)" + " " + "\(lap.TyreAge.value)")
                                        .padding(8)
                                        .foregroundStyle(.white)
                                    
                                case "Sector 1":
                                    let driverFastestSector = driverObject.FastestSector1
                                    let curSector = convertLapTimeToSeconds(time: lap.Sector1Time.value)
                                    
                                    Text("\(lap.Sector1Time.value)")
                                        .foregroundStyle(Color.white)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(curSector.isNearlyEqual(to: driverFastestSector) ? curSector.isNearlyEqual(to: processor.sessionDatabase.FastestSector1) ? Color.purple : Color.green : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                    
                                case "Sector 2":
                                    let driverFastestSector = driverObject.FastestSector2
                                    let curSector = convertLapTimeToSeconds(time: lap.Sector2Time.value)
                                    
                                    Text("\(lap.Sector2Time.value)")
                                        .foregroundStyle(Color.white)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(curSector.isNearlyEqual(to: driverFastestSector) ? curSector.isNearlyEqual(to: processor.sessionDatabase.FastestSector2) ? Color.purple : Color.green : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                    
                                case "Sector 3":
                                    let driverFastestSector = driverObject.FastestSector3
                                    let curSector = convertLapTimeToSeconds(time: lap.Sector3Time.value)
                                    
                                    Text("\(lap.Sector3Time.value)")
                                        .foregroundStyle(Color.white)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(curSector.isNearlyEqual(to: driverFastestSector) ? curSector.isNearlyEqual(to: processor.sessionDatabase.FastestSector3) ? Color.purple : Color.green : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                    
                                case "ST1":
                                    Text("\(lap.Sector1SpeedTrap.value)")
                                        .padding(8)
                                        .foregroundStyle(Color.white)
                                    
                                case "ST2":
                                    Text("\(lap.Sector2SpeedTrap.value)")
                                        .padding(8)
                                        .foregroundStyle(Color.white)
                                    
                                case "ST3":
                                    Text("\(lap.FinishLineSpeedTrap.value)")
                                        .padding(8)
                                        .foregroundStyle(Color.white)
                                    
                                default:
                                    Text("")
                                }
                            }
                            .frame(maxWidth: .infinity) // Column width is as large as largest item width
                            .background(j % 2 == 0 ? Color(UIColor.lightGray) : Color(UIColor.darkGray)) // Alternate row colours
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}
