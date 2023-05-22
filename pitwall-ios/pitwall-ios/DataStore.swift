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
    
    var sessionType: String
    var driverList: [String]
    
    init(sessionType: String, driverList: [String]) {

        self.sessionType = sessionType
        self.driverList = driverList
        
        for driver in driverList {
            driverDatabase[driver] = Driver(racingNum: driver)
        }
    }
    
    func sortByLapTime(driverList: [String]) -> [String] {
        
        struct LapTimeStruct: Comparable {
            let driver: String
            let time: Float
            let timestamp: Double
            
            static func <(lhs: LapTimeStruct, rhs: LapTimeStruct) -> Bool {
                if lhs.time == rhs.time {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.time < rhs.time
            }
        }
        
        var lapTimesSorted = [LapTimeStruct]()
        for driver in driverList {
            let fastestLap = driverDatabase[driver]?.FastestLap ?? 0
            
            // The driver in 1st place crosses the finish line first. The rest of the drivers will have yet to register a lap
            // time and their fastestLap will be 0. Hence, just append these drivers in the current order they are in.
            if fastestLap == 0 {
                lapTimesSorted.append(LapTimeStruct(driver: driver, time: 0, timestamp: 0))
                continue
            }
            
            let temp = driverDatabase[driver]?.laps[String(fastestLap)]?.LapTime.components(separatedBy: "::")
            let timestamp = Double(temp?[1] ?? "") ?? 0
            let fastestLapTimeString = temp?[0] ?? ""
            let parts = fastestLapTimeString.components(separatedBy: ":")
            
            let fastestLapTime = ((Float(parts[0]) ?? 0) * 60) + (Float(parts[1]) ?? 0)
            lapTimesSorted.insertSorted(newItem: LapTimeStruct(driver: driver, time: fastestLapTime, timestamp: timestamp))
        }
        
        var res = [String]()
        for lapTime in lapTimesSorted {
            res.append(lapTime.driver)
        }
        
        return res
        
    }
    
    func convertLapTimeToFloat(time: String) -> Float {
        let parts = time.components(separatedBy: ":")
        return ((Float(parts[0]) ?? 0) * 60) + (Float(parts[1]) ?? 0)
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
//            driverList.remove(at: driverList.firstIndex(of: driverObject.racingNum) ?? 0)
//            driverList.insert(driverObject.racingNum, at: (Int(data) ?? 0) - 1)
        case "Retired":
            driverObject.Retired = true
        case "Fastest":
            let data = data.components(separatedBy: ",")
            if data[0] == "LapTime" {
                driverObject.FastestLap = Int(data[1]) ?? 1
                if sessionType != "RACE" {
                    driverList = sortByLapTime(driverList: driverList)
                }
            } else if data[0] == "Sector1" {
                driverObject.FastestSector1 = Int(data[1]) ?? 1
            } else if data[0] == "Sector2" {
                driverObject.FastestSector2 = Int(data[1]) ?? 1
            } else {
                driverObject.FastestSector3 = Int(data[1]) ?? 1
            }
            
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
                let channels = data[0].components(separatedBy: ",")
                if channels[0] == "OnTrack" {
                    driverObject.trackStatus = true
                } else {
                    driverObject.trackStatus = false
                }
                driverObject.X = Int(channels[1]) ?? 0
                driverObject.Y = Int(channels[2]) ?? 0
                driverObject.Z = Int(channels[3]) ?? 0
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
                driverObject.laps[data[1], setDefault: Lap()].LapTimeInSeconds = convertLapTimeToFloat(time: data[0])
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
                    driverObject.Sector1SpeedTrap = Int(data[1]) ?? 0
                } else if data[0] == "Sector2SpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].Sector2SpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.Sector2SpeedTrap = Int(data[1]) ?? 0
                } else if data[0] == "FinishLineSpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].FinishLineSpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.FinishLineSpeedTrap = Int(data[1]) ?? 0
                } else if data[0] == "BackStraightSpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap()].BackStraightSpeedTrap = data[1] + "::\(timestamp)"
                    driverObject.BackStraightSpeedTrap = Int(data[1]) ?? 0
                }
                
            case "PitIn":
                driverObject.laps[data[0], setDefault: Lap()].PitIn = "true" + "::\(timestamp)"
                driverObject.PitIn = true
                driverObject.PitOut = false
                
            case "PitOut":
                driverObject.laps[data[0], setDefault: Lap()].PitOut = "true" + "::\(timestamp)"
                driverObject.PitOut = true
                driverObject.PitIn = false
                
            case "DeletedLaps":
                driverObject.laps[data[0], setDefault: Lap()].Deleted = true
            default:
                return
            }            
        }
    }
}
