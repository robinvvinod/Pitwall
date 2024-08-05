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
    let dispatchQueue = DispatchQueue(label: "processRecordQueue", qos: .userInitiated)
        
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
    
    func process(record: SingleRecord) {
        if carSpecific.contains(record.topic) {
            addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
        } else if sessionSpecific.contains(record.topic) {
            addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
        } else {
            addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
        }
    }
    
    func processQueueWithDelay(startPoint: Int) async throws {
        var count = startPoint
        if dataQueue.isEmpty {
            return
        }
        dataQueue.sort{ $0 < $1 }
        var overallDelay: Double = 0
        var sleepTime: Double = 0
        let startTime = DispatchTime.now()
        let dispatchQueue = DispatchQueue(label: "processingDispatchQueue", qos: .userInitiated)
        while true {
            // No delay in processing first message in queue
            if count == startPoint {
                let record = dataQueue[count]
                await MainActor.run(body: {
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
                sleepTime = dataQueue[count].timestamp - dataQueue[count - 1].timestamp
                overallDelay += sleepTime
                dispatchQueue.asyncAfter(deadline: startTime + overallDelay) { [self] in // TODO: Remove reduction of delay
//                    print("topic: \(record.topic) key: \(record.key) value: \(record.value)")
                    if carSpecific.contains(record.topic) {
                        addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    } else if sessionSpecific.contains(record.topic) {
                        addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
                    } else {
                        addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    }
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                    }
                }
            }
            count += 1
            
            if sleepTime > 0 { // This shouldn't be here... since kafka consumer gets info topic by topic, timestamps are not in order (~200ms off)
                try await Task.sleep(until: .now + .seconds(sleepTime * 0.9), tolerance: .nanoseconds(1), clock: .continuous)

            }
            
        }
    }
    
    func processQueue(start: Int = 0) {
        dataQueue.sort{ $0 < $1 }
        var count = start
        while true {
            if count > dataQueue.count - 1 {
                dataQueue = []
                return
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
