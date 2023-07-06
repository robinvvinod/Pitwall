//
//  DriverObject.swift
//  pitwall-ios
//
//  Created by Robin on 11/5/23.
//

import Foundation

class Lap {
    // Historical data
    
    // Tyre type is only broadcast by backend whenever there is a change. Hence, when a new lap is created, value from previous lap
    // has to be carried over. There is only a timestamp attached if the tyre was changed that lap
    var TyreType: (value: String, timestamp: Double)
    
    init(TyreType: (String, Double)) {
        self.TyreType = TyreType
    }
    
    // Stream data
    var GapToLeader: [(value: Float, timestamp: Double)] = []
    var IntervalToPositionAhead: [(value: Float, timestamp: Double)] = []
    var CarData: [(value: String, timestamp: Double)] = []
    var PositionData: [(value: String, timestamp: Double)] = []
    
    // Set once per lap
    var LapTime: (value: String, timestamp: Double) = ("-", 0)
    var TyreAge: (value: Int, timestamp: Double) = (0, 0)
    var Sector1Time: (value: String, timestamp: Double) = ("-", 0)
    var Sector2Time: (value: String, timestamp: Double) = ("-", 0)
    var Sector3Time: (value: String, timestamp: Double) = ("-", 0)
    var Sector1SpeedTrap: (value: Int, timestamp: Double) = (0, 0)
    var Sector2SpeedTrap: (value: Int, timestamp: Double) = (0, 0)
    var FinishLineSpeedTrap: (value: Int, timestamp: Double) = (0, 0)
    var BackStraightSpeedTrap: (value: Int, timestamp: Double) = (0, 0)
    var PitIn: (value: Bool, timestamp: Double) = (false, 0)
    var PitOut: (value: Bool, timestamp: Double) = (false, 0)
    var Deleted: Bool = false
    var StartTime: Double = 0
}

class Driver {
    let racingNum: String
    
    init(racingNum: String) {
        self.racingNum = racingNum
    }
    
    var laps: [String:Lap] = [:]
    var FastestLap: Lap?

    // Live data, shows current status of any value
    var CurrentLap: Int = 0
    var NumberOfPitStops: Int = 0
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
    var CurrentLap: Int = 0
    var TotalLaps: Int = 1
    var StartTime = ""
    var EndTime = ""
    var RCM: [String] = []
    var FastestLapTime: Float = Float.greatestFiniteMagnitude
    var FastestSector1: Float = Float.greatestFiniteMagnitude
    var FastestSector2: Float = Float.greatestFiniteMagnitude
    var FastestSector3: Float = Float.greatestFiniteMagnitude
}

