//
//  DataObject.swift
//  pitwall-ios
//
//  Created by Robin on 5/5/23.
//

import Foundation

// If key does not exist in dict, create it and set it to a default value
extension Dictionary {
    subscript(key: Key, setDefault defaultValue: @autoclosure () -> Value) -> Value {
        mutating get {
            return self[key] ?? {
                let value = defaultValue()
                self[key] = value
                return value
            }()
        }
    }
}

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
        
        let data = value.components(separatedBy: "::")[0]

        switch topic {
        case "CurrentLap":
            driverObject.CurrentLap = data
        case "NumberOfPitStops":
            driverObject.NumberOfPitStops = data
        case "Position":
            driverObject.Position.append(Int(data) ?? 0)
            driverList.remove(at: driverList.firstIndex(of: driverObject.racingNum) ?? 0)
            driverList.insert(driverObject.racingNum, at: (Int(data) ?? 0) - 1)
        case "Retired":
            driverObject.Retired = data
        default:
            return
        }
    }

    func addLapSpecificData(topic: String, driver: String, value: String) -> () {
        let driverObject = driverDatabase[driver]
        guard let driverObject = driverObject else {return}
        
        let temp = value.components(separatedBy: "::")
        let timestamp = temp[1]
        
        if (topic == "CarData") || (topic == "PositionData") {
          
            let data = temp[0].components(separatedBy: ";;")
            
            switch topic {
            case "CarData":
                driverObject.laps[data[1], setDefault: Lap()].CarData.append(data[0] + "::\(timestamp)")
                let channels = data[0].components(separatedBy: ",")
                driverObject.RPM = Int(channels[0]) ?? 0
                driverObject.Speed = Int(channels[1]) ?? 0
                driverObject.Gear = Int(channels[2]) ?? 0
                driverObject.Throttle = Int(channels[3]) ?? 0
                driverObject.Brake = Int(channels[4]) ?? 0
                driverObject.DRS = Int(channels[5]) ?? 0
            case "PositionData":
                driverObject.laps[data[1], setDefault: Lap()].PositionData.append(data[0] + "::\(timestamp)")
            default:
                return
            }
            
        } else if (topic == "GapToLeader") || (topic == "IntervalToPositionAhead") {
            
            let data = temp[0].components(separatedBy: ",")
            
            switch topic {
            case "GapToLeader":
                driverObject.laps[data[1], setDefault: Lap()].GapToLeader.append(data[0] + "::\(timestamp)")
                driverObject.GapToLeader = data[0]
            case "IntervalToPositionAhead":
                driverObject.laps[data[1], setDefault: Lap()].IntervalToPositionAhead.append(data[0] + "::\(timestamp)")
                driverObject.IntervalToPositionAhead = data[0]
            default:
                return
            }
            
        } else {
            
            let data = temp[0].components(separatedBy: ",")
            
            switch topic {
            case "TyreAge":
                driverObject.laps[data[2], setDefault: Lap()].TyreAge = data[0] + "::\(timestamp)"
                driverObject.TyreAge = Int(data[0]) ?? 0
                
            case "LapTime":
                driverObject.laps[data[1], setDefault: Lap()].LapTime = data[0] + "::\(timestamp)"
                driverObject.LapTime = data[0]
                
            case "Tyre":
                driverObject.laps[data[2], setDefault: Lap()].TyreType = data[0] + "::\(timestamp)"
                driverObject.TyreType = data[0]
                
            case "SectorTime":
                if data[1] == "1" {
                    driverObject.laps[data[2], setDefault: Lap()].Sector1Time = data[0] + "::\(timestamp)"
                    driverObject.Sector1Time = data[0]
                } else if data[1] == "2" {
                    driverObject.laps[data[2], setDefault: Lap()].Sector2Time = data[0] + "::\(timestamp)"
                    driverObject.Sector2Time = data[0]
                } else if data[1] == "3" {
                    driverObject.laps[data[2], setDefault: Lap()].Sector3Time = data[0] + "::\(timestamp)"
                    driverObject.Sector3Time = data[0]
                }
                
            case "Speed":
                if data[0] == "Sector1SpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].Sector1SpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.Sector1SpeedTrap = Float(data[1]) ?? 0
                } else if data[0] == "Sector2SpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].Sector2SpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.Sector2SpeedTrap = Float(data[1]) ?? 0
                } else if data[0] == "FinishLineSpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].FinishLineSpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.FinishLineSpeedTrap = Float(data[1]) ?? 0
                } else if data[0] == "BackStraightSpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].BackStraightSpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.BackStraightSpeedTrap = Float(data[1]) ?? 0
                }
                
            case "PitIn":
                driverObject.laps[data[0], setDefault: Lap()].PitIn = "true" + "::\(timestamp)"
                driverObject.PitIn = true
                driverObject.PitOut = false
                
            case "PitOut":
                driverObject.laps[data[0], setDefault: Lap()].PitOut = "true" + "::\(timestamp)"
                driverObject.PitOut = true
                driverObject.PitIn = false
                
            default:
                return
            }            
        }
    }
}
