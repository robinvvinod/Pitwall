//
//  DriverObject.swift
//  pitwall-ios
//
//  Created by Robin on 11/5/23.
//

import Foundation

class Lap {
    // Historical data
    // All these values are strings as they contain timestamps attached
    
    // Stream data
    var GapToLeader: [String] = []
    var IntervalToPositionAhead: [String] = []
    var CarData: [String] = []
    var PositionData: [String] = []
    
    // Set once per lap
    var LapTime: String = ""
    var StintNumber: String = ""
    var TyreAge: String = ""
    var TyreType: String = ""
    var Sector1Time: String = ""
    var Sector2Time: String = ""
    var Sector3Time: String = ""
    var Sector1SpeedTrap: String = ""
    var Sector2SpeedTrap: String = ""
    var FinishLineSpeedTrap: String = ""
    var BackStraightSpeedTrap: String = ""
    var PitIn: String = ""
    var PitOut: String = ""
}

class Driver {
    let racingNum: String
    
    init(racingNum: String) {
        self.racingNum = racingNum
    }
    
    // Live data
    var CurrentLap = "0"
    var NumberOfPitStops = "0"
    var Position: [Int] = []
    var Retired = "false"
    var laps: [String:Lap] = [:]
    
    var GapToLeader: String = ""
    var IntervalToPositionAhead: String = ""
    var CarData: String = ""
    var PositionData: String = ""
    var LapTime: String = ""
    var StintNumber: Int = 0
    var TyreAge: Int = 0
    var TyreType: String = ""
    var Sector1Time: String = ""
    var Sector2Time: String = ""
    var Sector3Time: String = ""
    var PitIn: Bool = false
    var PitOut: Bool = false
    var Sector1SpeedTrap: Float = 0
    var Sector2SpeedTrap: Float = 0
    var FinishLineSpeedTrap: Float = 0
    var BackStraightSpeedTrap: Float = 0
}

struct Session {
    var CurrentLap = "0"
    var TotalLaps = "0"
    var StartTime = ""
    var EndTime = ""
    var RCM: [String] = []
}

