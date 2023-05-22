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
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Text("Driver")
                    .padding(8)
                    .font(.headline)
                    .foregroundColor(Color.black)
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
    }
    
    var leaderboardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<headersArray.count, id: \.self) { i in
                    VStack(spacing: 0) {
                        Text("\(headersArray[i])")
                            .padding(8)
                            .font(.headline)
                            .foregroundColor(Color.black)
                        
                        let overallFastestLap = processor.driverDatabase[processor.driverList[0]]?.FastestLap?.LapTimeInSeconds ?? 0
                        ForEach(0..<processor.driverList.count, id: \.self) { j in
                            let fastestLap = processor.driverDatabase[processor.driverList[j]]?.FastestLap ?? Lap()
                            
                            HStack(spacing: 0) {
                                switch headersArray[i] {
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
                                    } else {
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
                            .frame(maxWidth: .infinity)
                            .background(j % 2 == 0 ? Color.gray : Color.black)
                        }
                    }.fixedSize(horizontal: true, vertical: false)
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
