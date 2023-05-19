//
//  LeaderboardView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI

struct LeaderboardView: View {
    
    @EnvironmentObject var processor: DataProcessor
    let headersArray: [String]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ScrollView(.horizontal, showsIndicators: false) {
                
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<headersArray.count, id: \.self) { i in
                        VStack(spacing: 0) {
                            Text("\(headersArray[i])")
                                .padding(8)
                            ForEach(0..<processor.driverList.count, id: \.self) { j in
                                let key = processor.driverList[j]
                                HStack(spacing: 0) {
                                    switch headersArray[i] {
                                    case "Car Number":
                                        Text(key)
                                            .foregroundColor(Color.white)
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Lap Time":
                                        Text("\(processor.driverDatabase[key]!.LapTime)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Gap":
                                        Text("\(processor.driverDatabase[key]!.GapToLeader)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Int":
                                        Text("\(processor.driverDatabase[key]!.IntervalToPositionAhead)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Tyre":
                                        Text("\(processor.driverDatabase[key]!.TyreAge) ")
                                            .padding(.vertical, 8)
                                            .padding(.leading, 8)
                                            .foregroundColor(Color.white)
                                        Text("\(processor.driverDatabase[key]!.TyreType)")
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 8)
                                            .foregroundColor(Color.white)
                                    case "Sector 1":
                                        Text("\(processor.driverDatabase[key]!.Sector1Time)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Sector 2":
                                        Text("\(processor.driverDatabase[key]!.Sector2Time)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Sector 3":
                                        Text("\(processor.driverDatabase[key]!.Sector3Time)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "ST1":
                                        Text("\(processor.driverDatabase[key]!.Sector1SpeedTrap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "ST2":
                                        Text("\(processor.driverDatabase[key]!.Sector2SpeedTrap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "ST3":
                                        Text("\(processor.driverDatabase[key]!.FinishLineSpeedTrap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Pit":
                                        if processor.driverDatabase[key]!.PitIn == false && processor.driverDatabase[key]!.PitOut == true {
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
                                        Text("\(processor.driverDatabase[key]!.NumberOfPitStops)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Lap":
                                        Text("\(processor.driverDatabase[key]!.CurrentLap)")
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
            }.padding()
        }.padding(.top, 1)
    }

}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
