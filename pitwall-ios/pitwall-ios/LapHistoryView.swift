//
//  LapHistoryView.swift
//  pitwall-ios
//
//  Created by Robin on 27/5/23.
//

import SwiftUI

struct LapHistoryView: View {
    
    let driver: String
    let headersArray: [String] // Order of items in headersArray controls the order of columns in the view. User preference
    @EnvironmentObject var processor: DataProcessor
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            lapNumberView
            ScrollView(.horizontal, showsIndicators: false) {
                historyView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(radius: 10)
        )
        .padding()
    }
    
    var lapNumberView: some View {
        VStack(spacing: 0) {
            // Set column heading
            Text("Lap")
                .padding(8)
                .font(.headline)
                .foregroundColor(Color.black)
            ForEach(1...(processor.driverDatabase[driver]?.CurrentLap ?? 1), id: \.self) { j in
                HStack {
                    Text(String(j))
                        .foregroundColor(Color.white)
                        .padding(8)
                        .foregroundColor(Color.white)
                }
                .frame(maxWidth: .infinity)
                .background(j % 2 == 0 ? Color.gray : Color.black) // Alternate row colours
            }
            
        }.fixedSize(horizontal: true, vertical: false)
    }
    
    var historyView: some View {
        // HStack contains a VStack column for each item in headersArray
        HStack(spacing: 0) {
            
            ForEach(0..<headersArray.count, id: \.self) { i in
                VStack(spacing: 0) {
                    // Set heading for column
                    Text("\(headersArray[i])")
                        .padding(8)
                        .font(.headline)
                        .foregroundColor(Color.black)
                    
                    ForEach(1...(processor.driverDatabase[driver]?.CurrentLap ?? 1), id: \.self) { j in
                        HStack { // HStack in case any column has more than 1 data point inside. E.g) Tyre
                            let lap = processor.driverDatabase[driver]?.laps[String(j)] ?? Lap(TyreType: ("", ""))
                            switch headersArray[i] {
                            case "Lap Time":
                                let driverFastestLap = processor.driverDatabase[driver]?.FastestLapTime ?? 0
                                let curLap = convertLapTimeToSeconds(time: lap.LapTime.value)
                                
                                Text("\(lap.LapTime.value)")
                                    .foregroundColor(Color.white)
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
                                        .foregroundColor(Color.white)
                                } else { // First driver has no gap to fastest lap attribute
                                    Text("+0.000")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                }
                                
                            case "Tyre":
                                Text("\(lap.TyreAge.value)")
                                    .padding(.vertical, 8)
                                    .padding(.leading, 8)
                                    .foregroundColor(Color.white)
                                Text("\(lap.TyreType.value)")
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 8)
                                    .foregroundColor(Color.white)
                                
                            case "Sector 1":
                                let driverFastestSector = processor.driverDatabase[driver]?.FastestSector1 ?? 0
                                let curSector = convertLapTimeToSeconds(time: lap.Sector1Time.value)
                                
                                Text("\(lap.Sector1Time.value)")
                                    .foregroundColor(Color.white)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 8)
                                    .background(curSector.isNearlyEqual(to: driverFastestSector) ? curSector.isNearlyEqual(to: processor.sessionDatabase.FastestSector1) ? Color.purple : Color.green : nil)
                                    .cornerRadius(15)
                                    .padding(.vertical, 6)
                                
                            case "Sector 2":
                                let driverFastestSector = processor.driverDatabase[driver]?.FastestSector2 ?? 0
                                let curSector = convertLapTimeToSeconds(time: lap.Sector2Time.value)
                                
                                Text("\(lap.Sector2Time.value)")
                                    .foregroundColor(Color.white)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 8)
                                    .background(curSector.isNearlyEqual(to: driverFastestSector) ? curSector.isNearlyEqual(to: processor.sessionDatabase.FastestSector2) ? Color.purple : Color.green : nil)
                                    .cornerRadius(15)
                                    .padding(.vertical, 6)
                                
                            case "Sector 3":
                                let driverFastestSector = processor.driverDatabase[driver]?.FastestSector3 ?? 0
                                let curSector = convertLapTimeToSeconds(time: lap.Sector3Time.value)
                                
                                Text("\(lap.Sector3Time.value)")
                                    .foregroundColor(Color.white)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 8)
                                    .background(curSector.isNearlyEqual(to: driverFastestSector) ? curSector.isNearlyEqual(to: processor.sessionDatabase.FastestSector3) ? Color.purple : Color.green : nil)
                                    .cornerRadius(15)
                                    .padding(.vertical, 6)
                                
                            case "ST1":
                                Text("\(lap.Sector1SpeedTrap.value)")
                                    .padding(8)
                                    .foregroundColor(Color.white)
                                
                            case "ST2":
                                Text("\(lap.Sector2SpeedTrap.value)")
                                    .padding(8)
                                    .foregroundColor(Color.white)
                                
                            case "ST3":
                                Text("\(lap.FinishLineSpeedTrap.value)")
                                    .padding(8)
                                    .foregroundColor(Color.white)
                                
                            default:
                                Text("")
                            }
                        }
                        .frame(maxWidth: .infinity) // Column width is as large as largest item width
                        .background(j % 2 == 0 ? Color.gray : Color.black)
                    }
                }.fixedSize(horizontal: true, vertical: false) // Allows each row item to scale horizontally
            }
        }
    }
}
