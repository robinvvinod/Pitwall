//
//  LeaderboardView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI

struct LeaderboardView: View {
    
    @EnvironmentObject var processor: DataProcessor
    let headersArray: [String] // Order of items in headersArray controls the order of columns in the view. User preference
    let sessionType: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sortedDriverListView // VStack column of all driver numbers, sorted according to fastest lap times/race position
            // Columns to the right of sortedDriverListView are horizontally scrollable
            if sessionType != "RACE" {
                nonRaceLeaderboardView // HStack of multiple VStack columns containing leaderboard data, sorted by lap times/race position
            } else {
                leaderboardView // HStack of multiple VStack columns containing leaderboard data, sorted by lap times/race position
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
    
    var sortedDriverListView: some View {
        VStack(spacing: 0) {
            // Set column heading
            Text("Driver")
                .padding(8)
                .font(.headline)
                .foregroundColor(Color.black)
            // processor.driverList is sorted according to fastest lap times/race position
            // Iterate through each item to create sorted column of driver numbers
            ForEach(0..<processor.driverList.count, id: \.self) { j in
                HStack(spacing: 0) {
                    // Racing number
                    Text(processor.driverList[j])
                        .foregroundColor(Color.white)
                        .padding(8)
                        .foregroundColor(Color.white)
                    
                    // TODO: Add driver name and team colour in addition to racing numbers
                }
                    .frame(maxWidth: .infinity)
                    .background(j % 2 == 0 ? Color.gray : Color.black) // Alternate row colours
            }
        }.fixedSize(horizontal: true, vertical: false)
    }
    
    var nonRaceLeaderboardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // HStack contains a VStack column for each item in headersArray
            HStack(spacing: 0) {
                // overallFastestLap is used to determine the gap to 1st place for indivdual drivers
                let overallFastestLap = processor.driverDatabase[processor.driverList[0]]?.FastestLap?.LapTimeInSeconds ?? 0
                
                ForEach(0..<headersArray.count, id: \.self) { i in
                    VStack(spacing: 0) {
                        // Set heading for column
                        Text("\(headersArray[i])")
                            .padding(8)
                            .font(.headline)
                            .foregroundColor(Color.black)
                        
                        // Iterate through each driver to create rows sorted according to lap time
                        ForEach(0..<processor.driverList.count, id: \.self) { j in
                            
                            // Lap object is retrieved for the fastest lap of given driver
                            let fastestLap = processor.driverDatabase[processor.driverList[j]]?.FastestLap ?? Lap()
                            
                            HStack(spacing: 0) { // HStack in case any column has more than 1 data point inside. E.g) Tyre
                                switch headersArray[i] {
                                // Each item has a timestamp attached that needs to be filtered
                                case "Lap Time":
                                    Text("\(fastestLap.LapTime.components(separatedBy: "::")[0])")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                    
                                case "Gap":
                                    if j != 0 {
                                        let gap = String(format: "%.3f", fastestLap.LapTimeInSeconds - overallFastestLap)
                                        Text("+\(gap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    } else { // First driver has no gap to fastest lap attribute
                                        Text("+0.000")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    }
                                    
                                case "Tyre":
                                    Text("\(fastestLap.TyreAge.components(separatedBy: "::")[0])")
                                        .padding(.vertical, 8)
                                        .padding(.leading, 8)
                                        .foregroundColor(Color.white)
                                    Text("\(fastestLap.TyreType)")
                                        .padding(.vertical, 8)
                                        .padding(.trailing, 8)
                                        .foregroundColor(Color.white)
                                    
                                case "Sector 1":
                                    Text("\(fastestLap.Sector1Time.components(separatedBy: "::")[0])")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                    
                                case "Sector 2":
                                    Text("\(fastestLap.Sector2Time.components(separatedBy: "::")[0])")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                    
                                case "Sector 3":
                                    Text("\(fastestLap.Sector3Time.components(separatedBy: "::")[0])")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                    
                                case "ST1":
                                    Text("\(fastestLap.Sector1SpeedTrap.components(separatedBy: "::")[0])")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                    
                                case "ST2":
                                    Text("\(fastestLap.Sector2SpeedTrap.components(separatedBy: "::")[0])")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                    
                                case "ST3":
                                    Text("\(fastestLap.FinishLineSpeedTrap.components(separatedBy: "::")[0])")
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
    
    var leaderboardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // HStack contains a VStack column for each item in headersArray
            HStack(alignment: .top, spacing: 0) {
                
                ForEach(0..<headersArray.count, id: \.self) { i in
                    
                    VStack(spacing: 0) {
                        // Set heading for column
                        Text("\(headersArray[i])")
                            .padding(8)
                        
                        // Iterate through each driver to create rows sorted according to lap time
                        ForEach(0..<processor.driverList.count, id: \.self) { j in
                            
                            // Driver object is retrieved for the given driver
                            let driverObject = processor.driverDatabase[processor.driverList[j]]
                            if let driverObject = driverObject {
                                
                                HStack(spacing: 0) { // HStack in case any column has more than 1 data point inside. E.g) Tyre
                                    switch headersArray[i] {
                                    case "Gap":
                                        Text("\(driverObject.GapToLeader)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                        
                                    case "Int":
                                        Text("\(driverObject.IntervalToPositionAhead)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                        
                                    case "Tyre":
                                        Text("\(driverObject.TyreAge) ")
                                            .padding(.vertical, 8)
                                            .padding(.leading, 8)
                                            .foregroundColor(Color.white)
                                        
                                        Text("\(driverObject.TyreType)")
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 8)
                                            .foregroundColor(Color.white)
                                        
                                    case "Pit":
                                        if driverObject.PitIn == false && driverObject.PitOut == true {
                                            Text("-")
                                                .padding(8)
                                                .foregroundColor(Color.white)
                                        } else {
                                            Text("IN")
                                                .padding(8)
                                                .foregroundColor(Color.white)
                                                .background(Color.green)
                                        }
                                        
                                    case "Stops":
                                        Text("\(driverObject.NumberOfPitStops)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                        
                                    case "Lap":
                                        Text("\(driverObject.CurrentLap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                        
                                    default:
                                        Text("")
                                    }
                                }
                                .frame(maxWidth: .infinity) // Column width is as large as largest item width/
                                .background(j % 2 == 0 ? Color.gray : Color.black)
                            }
                        }
                    }.fixedSize(horizontal: true, vertical: false) // Allows each row item to scale horizontally
                }
            }
        }
    }
}

struct NonRaceLeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
