//
//  DataProcessor.swift
//  pitwall-ios
//
//  Created by Robin on 4/5/23.
//

import Foundation

class DataProcessor: DataStore {
    
    struct SingleRecord: Comparable {
        let topic: String
        let key: String
        let value: String
        let timestamp: Double
        
        static func <(lhs: SingleRecord, rhs: SingleRecord) -> Bool {
            return lhs.timestamp < rhs.timestamp
        }
    }
    
    let carSpecific = ["CurrentLap", "NumberOfPitStops", "Position", "Retired", "Fastest"]
    let sessionSpecific = ["LapCount", "SessionStatus", "TotalLaps", "RCM"]
    
    var dataQueue: [SingleRecord] = []
        
    func addtoQueue(records: [[String:AnyObject]]) async throws -> () {
        for record in records {
            let topic = record["topic"] as? String
            let key = (record["key"] as? String)?.base64Decoded()
            let value = (record["value"] as? String)?.base64Decoded()
            
            if let topic = topic, let key = key, let value = value {
                guard let timestamp = Double(value.components(separatedBy: "::").last ?? "0") else {return}
                //dataQueue.insertSorted(newItem: SingleRecord(topic: topic, key: key, value: value, timestamp: timestamp))
                dataQueue.append(SingleRecord(topic: topic, key: key, value: value, timestamp: timestamp))
            } else {return}
        }
    }
    
    func processQueueWithDelay(startPoint: Int) async -> () {
        var count = startPoint
        if dataQueue.isEmpty {
            return
        }
        dataQueue.sort{ $0 < $1 }
        var delay: Double = 0
        while true {
            // No delay in processing first message in queue
            if count == startPoint {
                let record = dataQueue[count]
                await MainActor.run(body: {
//                    print("topic: \(record.topic) key: \(record.key) value: \(record.value)")
                    if carSpecific.contains(record.topic) {
                        addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    } else if sessionSpecific.contains(record.topic) {
                        addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
                    } else {
                        addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    }
                    objectWillChange.send()
                })
            } else { // Not the first message in the queue, possible delay
                if count > dataQueue.count - 1 {
                    if sessionDatabase.EndTime != "" {
                        return // Session has ended and all messages in queue were processed
                    } else {
                        /*
                        If this condition is reached and it is not the last message for the session, retrieving of messages from Kafka
                        is slower than the delay behind the live stream. TODO: Handle this case by notifying user about slow network.
                        */
                        return
                    }
                }
                
                let record = dataQueue[count]                
                delay += dataQueue[count].timestamp - dataQueue[count - 1].timestamp
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                    if carSpecific.contains(record.topic) {
                        addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    } else if sessionSpecific.contains(record.topic) {
                        addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
                    } else {
                        addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    }
                    objectWillChange.send()
                }
            }
            count += 1
        }
    }
    
    func processQueue() async -> () {
        var count = 0
        if dataQueue.isEmpty {
            return
        }
        dataQueue.sort{ $0 < $1 }
        while true {
            if count > dataQueue.count - 1 {
                if sessionDatabase.EndTime != "" {
                    return // Session has ended and all messages in queue were processed
                } else {
                    /*
                    If this condition is reached and it is not the last message for the session, retrieving of messages from Kafka
                    is slower than the delay behind the live stream. TODO: Handle this case by notifying user about slow network.
                    */
                    return
                }
            }
            
            let record = dataQueue[count]
            if carSpecific.contains(record.topic) {
                addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
            } else if sessionSpecific.contains(record.topic) {
                addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
            } else {
                addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
            }
            count += 1
        }
    }
    
}
