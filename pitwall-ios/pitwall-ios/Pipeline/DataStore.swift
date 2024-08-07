//
//  DataStore.swift
//  pitwall-ios
//
//  Created by Robin on 5/5/23.
//

import Foundation

class DataStore: ObservableObject {
    
    var driverDatabase: [String:Driver] = [:]
    var sessionDatabase: Session = Session()
    let driverInfo: DriverInfo = DriverInfo()
    
    var sessionType: String
    var driverList: [String]
    
    init(sessionType: String, driverList: [String]) {

        self.sessionType = sessionType
        self.driverList = driverList
        
        for driver in driverList {
            driverDatabase[driver] = Driver(racingNum: driver)
        }
    }
    
    private func sortByLapTime(driverList: [String]) -> [String] {
        
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
            let fastestLap = driverDatabase[driver]?.FastestLap
            if let fastestLap = fastestLap {
                lapTimesSorted.insertSorted(newItem: LapTimeStruct(driver: driver, time: convertLapTimeToSeconds(time: fastestLap.LapTime.value), timestamp: fastestLap.LapTime.timestamp))
            }
            else {
                // The driver in 1st place crosses the finish line first. The rest of the drivers will have yet to register a lap
                // time and their fastestLap will be nil. Hence, just append these drivers in the current order they are in.
                lapTimesSorted.append(LapTimeStruct(driver: driver, time: 0, timestamp: 0))
            }
        }
        
        var res = [String]()
        for lapTime in lapTimesSorted {
            res.append(lapTime.driver)
        }
        
        return res
        
    }
        
    func addSessionSpecificData(topic: String, key: String, value: String) -> () {
        switch topic {
        case "TotalLaps":
            sessionDatabase.TotalLaps = Int(value) ?? 0
        case "LapCount":
            sessionDatabase.CurrentLap = Int(value) ?? 0
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
            driverObject.CurrentLap = Int(data) ?? 0
            let timestamp = Double(value.components(separatedBy: "::")[1]) ?? 0
            driverObject.laps[data, setDefault: Lap(TyreType: (driverObject.TyreType,0))].StartTime = timestamp
        case "NumberOfPitStops":
            driverObject.NumberOfPitStops = Int(data) ?? 0
        case "Position":
            driverObject.Position.append(Int(data) ?? 0)
            driverList.remove(at: driverList.firstIndex(of: driverObject.racingNum) ?? 0)
            driverList.insert(driverObject.racingNum, at: (Int(data) ?? 0) - 1)
        case "Retired":
            driverObject.Retired = true
        case "Fastest":
            let data = data.components(separatedBy: ",")
            if data[0] == "LapTime" {
                driverObject.FastestLap = driverObject.laps[data[1]]
                driverObject.FastestLapTime = convertLapTimeToSeconds(time: driverObject.FastestLap?.LapTime.value ?? "")
                if driverObject.FastestLapTime < sessionDatabase.FastestLapTime {
                    sessionDatabase.FastestLapTime = driverObject.FastestLapTime
                }
                
                // In non-race sessions, leaderboard is sorted by fastest lap times.
                if sessionType != "RACE" {
                    driverList = sortByLapTime(driverList: driverList)
                }
            } else if data[0] == "Sector1" {
                driverObject.FastestSector1 = convertLapTimeToSeconds(time: data[1])
                if driverObject.FastestSector1 < sessionDatabase.FastestSector1 {
                    sessionDatabase.FastestSector1 = driverObject.FastestSector1
                }
            } else if data[0] == "Sector2" {
                driverObject.FastestSector2 = convertLapTimeToSeconds(time: data[1])
                if driverObject.FastestSector2 < sessionDatabase.FastestSector2 {
                    sessionDatabase.FastestSector2 = driverObject.FastestSector2
                }
            } else {
                driverObject.FastestSector3 = convertLapTimeToSeconds(time: data[1])
                if driverObject.FastestSector3 < sessionDatabase.FastestSector3 {
                    sessionDatabase.FastestSector3 = driverObject.FastestSector3
                }
            }
            
        default:
            return
        }
    }

    func addLapSpecificData(topic: String, driver: String, value: String) -> () {
        let driverObject = driverDatabase[driver]
        guard let driverObject = driverObject else {return}
        
        let temp = value.components(separatedBy: "::")
        let timestamp = Double(temp[1]) ?? 0
        
        if (topic == "CarData") || (topic == "PositionData") {
          
            let data = temp[0].components(separatedBy: ";;")
            
            switch topic {
            case "CarData":
                driverObject.laps[data[1], setDefault: Lap(TyreType: (driverObject.TyreType,0))].CarData.append((data[0], timestamp))
                let channels = data[0].components(separatedBy: ",")
                driverObject.RPM = Int(channels[0]) ?? 0
                driverObject.Speed = Int(channels[1]) ?? 0
                driverObject.Gear = Int(channels[2]) ?? 0
                driverObject.Throttle = Int(channels[3]) ?? 0
                driverObject.Brake = Int(channels[4]) ?? 0
                driverObject.DRS = Int(channels[5]) ?? 0
                
            case "PositionData":
                driverObject.laps[data[1], setDefault: Lap(TyreType: (driverObject.TyreType,0))].PositionData.append((data[0], timestamp))
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
                var gap = data[0]
                gap.remove(at: gap.startIndex)
                driverObject.laps[data[1], setDefault: Lap(TyreType: (driverObject.TyreType,0))].GapToLeader.append((value: Float(gap) ?? 0, timestamp: timestamp))
                driverObject.GapToLeader = data[0]
                
            case "IntervalToPositionAhead":
                var interval = data[0]
                interval.remove(at: interval.startIndex)
                driverObject.laps[data[1], setDefault: Lap(TyreType: (driverObject.TyreType,0))].IntervalToPositionAhead.append((value: Float(interval) ?? 0, timestamp: timestamp))
                driverObject.IntervalToPositionAhead = data[0]
            default:
                return
            }
            
        } else {
            
            let data = temp[0].components(separatedBy: ",")
            
            switch topic {
            case "TyreAge":
                let tyreAge = Int(data[0]) ?? 0
                driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].TyreAge = (tyreAge, timestamp)
                driverObject.TyreAge = tyreAge
                
            case "LapTime":
                driverObject.laps[data[1], setDefault: Lap(TyreType: (driverObject.TyreType,0))].LapTime = (data[0], timestamp)
                
            case "Tyre":
                driverObject.TyreType = data[0]
                driverObject.laps[data[2], setDefault: Lap(TyreType: (data[0], timestamp))].TyreType = (data[0], timestamp)
                
            case "SectorTime":
                if data[1] == "1" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].Sector1Time = (data[0], timestamp)
                } else if data[1] == "2" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].Sector2Time = (data[0], timestamp)
                } else if data[1] == "3" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].Sector3Time = (data[0], timestamp)
                }
                
            case "Speed":
                let speed = Int(data[1]) ?? 0
                if data[0] == "Sector1SpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].Sector1SpeedTrap = (speed, timestamp)
                } else if data[0] == "Sector2SpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].Sector2SpeedTrap = (speed, timestamp)
                } else if data[0] == "FinishLineSpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].FinishLineSpeedTrap = (speed, timestamp)
                } else if data[0] == "BackStraightSpeedTrap" {
                    driverObject.laps[data[2], setDefault: Lap(TyreType: (driverObject.TyreType,0))].BackStraightSpeedTrap = (speed, timestamp)
                }
                
            case "PitIn":
                driverObject.laps[data[0], setDefault: Lap(TyreType: (driverObject.TyreType,0))].PitIn = (true, timestamp)
                driverObject.PitIn = true
                driverObject.PitOut = false
                
            case "PitOut":
                driverObject.laps[data[0], setDefault: Lap(TyreType: (driverObject.TyreType,0))].PitOut = (true, timestamp)
                driverObject.PitOut = true
                driverObject.PitIn = false
                
            case "DeletedLaps":
                driverObject.laps[data[0], setDefault: Lap(TyreType: (driverObject.TyreType,0))].Deleted = true
                // If driver's fastest lap time was deleted, iterate through their previous laps to find next fastest lap
                var fastestLapTime = Float.greatestFiniteMagnitude
                var fastestLapKey: String = ""
                for (_, key_value) in driverObject.laps.enumerated() {
                    if key_value.value.Deleted == false {
                        let curLapTime = convertLapTimeToSeconds(time: key_value.value.LapTime.value)
                        if curLapTime < fastestLapTime {
                            fastestLapTime = curLapTime
                            fastestLapKey = key_value.key
                        }
                    }
                }
                driverObject.FastestLap = driverObject.laps[fastestLapKey]
                
            default:
                return
            }            
        }
    }
}
