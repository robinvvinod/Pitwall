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
    
    // Tyre type is only broadcast by backend whenever there is a change. Hence, when a new lap is created, value from previous lap
    // has to be carried over. There is only a timestamp attached if the tyre was changed that lap
    var TyreType: String
    
    init(TyreType: String) {
        self.TyreType = TyreType
    }
    
    // Stream data
    var GapToLeader: [String] = []
    var IntervalToPositionAhead: [String] = []
    var CarData: [String] = []
    var PositionData: [String] = []
    
    // Set once per lap
    var LapTime: String = "-"
    var TyreAge: String = "-"
    var Sector1Time: String = "-"
    var Sector2Time: String = "-"
    var Sector3Time: String = "-"
    var Sector1SpeedTrap: String = "-"
    var Sector2SpeedTrap: String = "-"
    var FinishLineSpeedTrap: String = "-"
    var BackStraightSpeedTrap: String = "-"
    var PitIn: String = "-"
    var PitOut: String = "-"
    var Deleted: Bool = false
}

class Driver {
    let racingNum: String
    
    init(racingNum: String) {
        self.racingNum = racingNum
    }
    
    var laps: [String:Lap] = [:]
    var FastestLap: Lap?

    // Live data, shows current status of any value
    var CurrentLap = "0"
    var NumberOfPitStops = "0"
    var Position: [Int] = []
    var Retired = false
    var GapToLeader: String = "-"
    var IntervalToPositionAhead: String = "-"
    var Speed: Int = 0
    var RPM: Int = 0
    var Gear: Int = 0
    var Throttle: Int = 0
    var Brake: Int = 0
    var DRS: Int = 0
    var X: Int = 0
    var Y: Int = 0
    var Z: Int = 0
    var trackStatus: Bool = false // On track or not
    var TyreAge: Int = 0
    var TyreType: String = "-"
    var PitIn: Bool = false
    var PitOut: Bool = false
    
    var FastestLapTime: Float = Float.greatestFiniteMagnitude
    var FastestSector1: Float = Float.greatestFiniteMagnitude
    var FastestSector2: Float = Float.greatestFiniteMagnitude
    var FastestSector3: Float = Float.greatestFiniteMagnitude
}

struct Session {
    var CurrentLap = "0"
    var TotalLaps = "0"
    var StartTime = ""
    var EndTime = ""
    var RCM: [String] = []
    var FastestLapTime: Float = Float.greatestFiniteMagnitude
    var FastestSector1: Float = Float.greatestFiniteMagnitude
    var FastestSector2: Float = Float.greatestFiniteMagnitude
    var FastestSector3: Float = Float.greatestFiniteMagnitude
}

