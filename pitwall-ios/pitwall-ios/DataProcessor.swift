//
//  DataProcessor.swift
//  pitwall-ios
//
//  Created by Robin on 4/5/23.
//

import Foundation

extension String {
    func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }

    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

class DataProcessor: DataObject {
    
    let carSpecific = ["CurrentLap", "NumberOfPitStops", "Position", "Retired"]
    let sessionSpecific = ["LapCount", "SessionStatus", "TotalLaps", "RCM"]
        
    func processRecord(records: [[String:AnyObject]]) async throws -> () {
        for record in records {
            let topic = record["topic"] as? String
            let key = (record["key"] as? String)?.base64Decoded()
            let value = (record["value"] as? String)?.base64Decoded()
            
            if let topic = topic, let key = key, let value = value {
                await MainActor.run(body: {
                    
                    if carSpecific.contains(topic) {
                        addCarSpecificData(topic: topic, driver: key, value: value)
                    } else if sessionSpecific.contains(topic) {
                        return
                    } else {
                        addLapSpecificData(topic: topic, driver: key, value: value)
                    }
                   
                })
            } else {return}
        }
    }
}
