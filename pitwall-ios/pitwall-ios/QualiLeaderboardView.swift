//
//  QualiLeaderboardView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI

struct QualiLeaderboardView: View {
    
    @EnvironmentObject var processor: DataProcessor
    let headersArray: [String]
    @State var fastestLaps = [Lap]()
    
    func filterFastestLaps() -> [Lap] {
        var laps = [Lap]()
        for driver in processor.driverList {
            let fastestLapNumber = String(processor.driverDatabase[driver]?.FastestLap ?? 1)
            let fastestLap = processor.driverDatabase[driver]?.laps[fastestLapNumber] ?? Lap()
            laps.append(fastestLap)
        }
        return laps
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Driver")
                    .padding(8)
                    .font(.headline)
                ForEach(0..<processor.driverList.count, id: \.self) { j in
                    HStack(spacing: 0) {
                        Text(processor.driverList[j])
                            .foregroundColor(Color.white)
                            .padding(8)
                            .foregroundColor(Color.white)
                    }
                        .frame(maxWidth: .infinity)
                        .background(j % 2 == 0 ? Color.gray : Color.black)
                }
            }.fixedSize(horizontal: true, vertical: false)
            
            leaderboardView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(radius: 10)
        )
        .padding()
        .onAppear {
            fastestLaps = filterFastestLaps()
        }
        
    }
    
    var leaderboardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<headersArray.count, id: \.self) { i in
                    VStack(spacing: 0) {
                        Text("\(headersArray[i])")
                            .padding(8)
                            .font(.headline)
                        
                        ForEach(0..<fastestLaps.count, id: \.self) { j in
                            
                            let fastestLap = fastestLaps[j]
                            
                            HStack(spacing: 0) {
                                switch headersArray[i] {
                                case "Lap Time":
                                    Text("\(fastestLap.LapTime)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                case "Gap":
                                    if j != 0 {
                                        let gap = fastestLap.LapTimeInSeconds - fastestLaps[0].LapTimeInSeconds
                                        Text("+\(gap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    } else {
                                        Text("+0.000")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    }
                                    
                                case "Tyre":
                                    Text("\(fastestLap.TyreAge)")
                                        .padding(.vertical, 8)
                                        .padding(.leading, 8)
                                        .foregroundColor(Color.white)
                                    Text("\(fastestLap.TyreType)")
                                        .padding(.vertical, 8)
                                        .padding(.trailing, 8)
                                        .foregroundColor(Color.white)
                                case "Sector 1":
                                    Text("\(fastestLap.Sector1Time)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                case "Sector 2":
                                    Text("\(fastestLap.Sector2Time)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                case "Sector 3":
                                    Text("\(fastestLap.Sector3Time)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                case "ST1":
                                    Text("\(fastestLap.Sector1SpeedTrap)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                case "ST2":
                                    Text("\(fastestLap.Sector2SpeedTrap)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                case "ST3":
                                    Text("\(fastestLap.FinishLineSpeedTrap)")
                                        .padding(8)
                                        .foregroundColor(Color.white)
                                default:
                                    Text("")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .background(j % 2 == 0 ? Color.gray : Color.black)
                        }
                    }
                }
            }
        }

    }

}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
