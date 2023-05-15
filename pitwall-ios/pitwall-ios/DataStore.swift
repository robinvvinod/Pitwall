//
//  DataObject.swift
//  pitwall-ios
//
//  Created by Robin on 5/5/23.
//

import Foundation

class DataStore: ObservableObject {
    
    var driverDatabase: [String:Driver] = [:]
    var sessionDatabase: Session = Session()
    
    var driverList = ["16", "1", "11", "55", "44", "14", "4", "22", "18", "81", "63", "23", "77", "2", "24", "20", "10", "21", "31", "27"] // Sorted according to position of driver
    
    init() {
        for driver in driverList {
            driverDatabase[driver] = Driver(racingNum: driver)
        }
    }
    
    func addSessionSpecificData(topic: String, key: String, value: String) -> () {
        switch topic {
        case "TotalLaps":
            sessionDatabase.TotalLaps = value
        case "LapCount":
            sessionDatabase.CurrentLap = value
        case "SessionStatus":
            if key == "StartTime" {
                sessionDatabase.StartTime = value
            } else {
                sessionDatabase.EndTime = value
            }
        case "RCM":
            sessionDatabase.RCM.append(key + "," + value)
        default:
            return
        }
    }
    
    func addCarSpecificData(topic: String, driver: String, value: String) -> () {
        let driverObject = driverDatabase[driver]
        guard let driverObject = driverObject else {return}
        
        let value = value.components(separatedBy: "::")[0]

        switch topic {
        case "CurrentLap":
            driverObject.CurrentLap = value
        case "NumberOfPitStops":
            driverObject.NumberOfPitStops = value
        case "Position":
            driverObject.Position.append(Int(value) ?? 0)
            driverList.remove(at: driverList.firstIndex(of: driverObject.racingNum) ?? 0)
            driverList.insert(driverObject.racingNum, at: (Int(value) ?? 0) - 1)
        case "Retired":
            driverObject.Retired = value
        default:
            return
        }
    }

    func addLapSpecificData(topic: String, driver: String, value: String) -> () {
        let driverObject = driverDatabase[driver]
        guard let driverObject = driverObject else {return}
        
        let timestamp = value.components(separatedBy: "::")[1]
        
        if (topic == "CarData") || (topic == "PositionData") {
          
            let value = value.components(separatedBy: ";;")
            
            switch topic {
            case "CarData":
                driverObject.laps[value[1], default: Lap()].CarData.append(value[0] + "::\(timestamp)")
                let channels = value[0].components(separatedBy: ",")
                driverObject.RPM = Int(channels[0]) ?? 0
                driverObject.Speed = Int(channels[1]) ?? 0
                driverObject.Gear = Int(channels[2]) ?? 0
                driverObject.Throttle = Int(channels[3]) ?? 0
                driverObject.Brake = Int(channels[4]) ?? 0
                driverObject.DRS = Int(channels[5]) ?? 0
            case "PositionData":
                driverObject.laps[value[1], default: Lap()].PositionData.append(value[0] + "::\(timestamp)")
            default:
                return
            }
            
        } else if (topic == "GapToLeader") || (topic == "IntervalToPositionAhead") {
            
            let value = value.components(separatedBy: ",")
            
            switch topic {
            case "GapToLeader":
                driverObject.laps[value[1], default: Lap()].GapToLeader.append(value[0] + "::\(timestamp)")
                driverObject.GapToLeader = value[0]
            case "IntervalToPositionAhead":
                driverObject.laps[value[1], default: Lap()].IntervalToPositionAhead.append(value[0] + "::\(timestamp)")
                driverObject.IntervalToPositionAhead = value[0]
            default:
                return
            }
            
        } else {
            
            let value = value.components(separatedBy: ",")
            
            switch topic {
            case "TyreAge":
                driverObject.laps[value[2], default: Lap()].TyreAge = value[0] + "::\(timestamp)"
                driverObject.TyreAge = Int(value[0]) ?? 0
                
            case "LapTime":
                driverObject.laps[value[1], default: Lap()].LapTime = value[0] + "::\(timestamp)"
                driverObject.LapTime = value[0]
                
            case "Tyre":
                driverObject.laps[value[2], default: Lap()].TyreType = value[0] + "::\(timestamp)"
                driverObject.TyreType = value[0]
                
            case "SectorTime":
                if value[1] == "1" {
                    driverObject.laps[value[2], default: Lap()].Sector1Time = value[0] + "::\(timestamp)"
                    driverObject.Sector1Time = value[0]
                } else if value[1] == "2" {
                    driverObject.laps[value[2], default: Lap()].Sector2Time = value[0] + "::\(timestamp)"
                    driverObject.Sector2Time = value[0]
                } else if value[1] == "3" {
                    driverObject.laps[value[2], default: Lap()].Sector3Time = value[0] + "::\(timestamp)"
                    driverObject.Sector3Time = value[0]
                }
                
            case "Speed":
                if value[0] == "Sector1SpeedTrap" {
                    driverObject.laps[value[2], default: Lap()].Sector1SpeedTrap = value[1] + "::\(timestamp)"
                    driverObject.Sector1SpeedTrap = Float(value[1]) ?? 0
                } else if value[0] == "Sector2SpeedTrap" {
                    driverObject.laps[value[2], default: Lap()].Sector2SpeedTrap = value[1] + "::\(timestamp)"
                    driverObject.Sector2SpeedTrap = Float(value[1]) ?? 0
                } else if value[0] == "FinishLineSpeedTrap" {
                    driverObject.laps[value[2], default: Lap()].FinishLineSpeedTrap = value[1] + "::\(timestamp)"
                    driverObject.FinishLineSpeedTrap = Float(value[1]) ?? 0
                } else if value[0] == "BackStraightSpeedTrap" {
                    driverObject.laps[value[2], default: Lap()].BackStraightSpeedTrap = value[1] + "::\(timestamp)"
                    driverObject.BackStraightSpeedTrap = Float(value[1]) ?? 0
                }
                
            case "PitIn":
                driverObject.laps[value[0], default: Lap()].PitIn = "true" + "::\(timestamp)"
                driverObject.PitIn = true
                driverObject.PitOut = false
                
            case "PitOut":
                driverObject.laps[value[0], default: Lap()].PitOut = "true" + "::\(timestamp)"
                driverObject.PitOut = true
                driverObject.PitIn = false
                
            default:
                return
            }            
        }
    }
}
