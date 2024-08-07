//
//  DataProcessor.swift
//  pitwall-ios
//
//  Created by Robin on 4/5/23.
//

import Foundation

class DataProcessor: DataStore {
    
    private struct SingleRecord: Comparable {
        let topic: String
        let key: String
        let value: String
        let timestamp: Double
        
        static func <(lhs: SingleRecord, rhs: SingleRecord) -> Bool {
            return lhs.timestamp < rhs.timestamp
        }
    }
    
    private let carSpecific = ["CurrentLap", "NumberOfPitStops", "Position", "Retired", "Fastest"]
    private let sessionSpecific = ["LapCount", "SessionStatus", "TotalLaps", "RCM"]
            
    func addtoQueue(records: [[String:AnyObject]]) {
        for record in records {
            let topic = record["topic"] as? String
            let key = (record["key"] as? String)?.base64Decoded()
            let value = (record["value"] as? String)?.base64Decoded()
            
            if let topic = topic, let key = key, let value = value {
                guard let timestamp = Double(value.components(separatedBy: "::").last ?? "0") else {return}
                process(record: SingleRecord(topic: topic, key: key, value: value, timestamp: timestamp))
            } else {return}
        }
    }
    
    private func process(record: SingleRecord) {
        if carSpecific.contains(record.topic) {
            addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
        } else if sessionSpecific.contains(record.topic) {
            addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
        } else {
            addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
        }
    }
}
