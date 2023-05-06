//
//  DataObject.swift
//  pitwall-ios
//
//  Created by Robin on 5/5/23.
//

import Foundation

class Driver {
    
    let id = UUID()
    let racingNum: String
    
    init(racingNum: String) {
        self.racingNum = racingNum
    }
    
    var CurrentLap = "0"
    var NumberOfPitStops = "0"
    var Position = "0"
    var Retired = "false"
    var laps: [String:[String:String]] = [:]
    var CarData: [String:[String]] = [:]
    var PositionData: [String:[String]] = [:]
}

class Session {
    let id = UUID()
    var CurrentLap = "0"
    var TotalLaps = "0"
    var StartTime = "0"
    var EndTime = "0"
    var RCM: [String] = []
}

class DataObject: ObservableObject {
    
    @Published var driverDatabase: [String:Driver] = [:]
    @Published var sessionDatabase: Session = Session()
    
    let driverList = ["16", "1", "11", "55", "44", "14", "4", "22", "18", "81", "63", "23", "77", "2", "24", "20", "10", "21", "31", "27"]
    
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

        switch topic {
        case "CurrentLap":
            driverObject.CurrentLap = value
        case "NumberOfPitStops":
            driverObject.NumberOfPitStops = value
        case "Position":
            driverObject.Position = value
        case "Retired":
            driverObject.Retired = value
        default:
            return
        }
    }

    func addLapSpecificData(topic: String, driver: String, value: String) -> () {
        let driverObject = driverDatabase[driver]
        guard let driverObject = driverObject else {return}
        let curLap = driverObject.CurrentLap
        
        let timestamp = value.components(separatedBy: "::")[1]
        
        if (topic == "CarData") || (topic == "PositionData") {
          
            let value = value.components(separatedBy: ";;")
            
            switch topic {
            case "CarData":
                driverObject.CarData[value[1], default: []].append(value[0] + "::\(timestamp)")
                
            case "PositionData":
                driverObject.PositionData[value[1], default: []].append(value[0] + "::\(timestamp)")
            default:
                return
            }
            
            
        } else {
            
            let value = value.components(separatedBy: ",")
            
            switch topic {
            case "TyreAge":
                driverObject.laps[value[2], default: [:]]["TyreAge"] = value[0] + "::\(timestamp)"
                driverObject.laps[value[2], default: [:]]["StintNumber"] = value[1] + "::\(timestamp)"
            case "LapTime":
                driverObject.laps[value[1], default: [:]]["LapTime"] = value[0] + "::\(timestamp)"
            case "Tyre":
                driverObject.laps[value[2], default: [:]]["TyreType"] = value[0] + "::\(timestamp)"
                driverObject.laps[value[2], default: [:]]["StintNumber"] = value[1] + "::\(timestamp)"
            case "GapToLeader":
                driverObject.laps[value[1], default: [:]]["GapToLeader"] = value[0] + "::\(timestamp)"
            case "IntervalToPositionAhead":
                driverObject.laps[value[1], default: [:]]["IntervalToPositionAhead"] = value[0] + "::\(timestamp)"
            case "SectorTime":
                driverObject.laps[value[2], default: [:]]["Sector\(value[1])Time"] = value[0] + "::\(timestamp)"
            case "Speed":
                driverObject.laps[value[2], default: [:]][value[0]] = value[1] + "::\(timestamp)"
            case "PitIn":
                driverObject.laps[value[0], default: [:]]["PitIn"] = "true" + "::\(timestamp)"
            case "PitOut":
                driverObject.laps[value[0], default: [:]]["PitIn"] = "true" + "::\(timestamp)"
            default:
                return
            }
            
            print(driverObject.laps)
        }
    }
}
