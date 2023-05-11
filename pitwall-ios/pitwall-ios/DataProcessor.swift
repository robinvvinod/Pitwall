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

extension Array where Element: Comparable {
    mutating func insertSorted(newItem item: Element) {
        let index = insertionIndexOf(elem: item) { $0 < $1 }
        insert(item, at: index)
    }
}

extension Array {
    //https://stackoverflow.com/a/26679191/8234523
    func insertionIndexOf(elem: Element, isOrderedBefore: (Element, Element) -> Bool) -> Int {
        var lo = 0
        var hi = self.count - 1
        while lo <= hi {
            let mid = (lo + hi)/2
            if isOrderedBefore(self[mid], elem) {
                lo = mid + 1
            } else if isOrderedBefore(elem, self[mid]) {
                hi = mid - 1
            } else {
                return mid
            }
        }
        return lo
    }
}

struct SingleRecord: Comparable {
    let topic: String
    let key: String
    let value: String
    let timestamp: Double
    
    static func <(lhs: SingleRecord, rhs: SingleRecord) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}

class DataProcessor: DataStore {
    
    let carSpecific = ["CurrentLap", "NumberOfPitStops", "Position", "Retired"]
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
    
    func processQueue(startPoint: Int) async -> () {
        var count = startPoint
        dataQueue.sort{ $0 < $1 }
        while true {
            if !dataQueue.isEmpty {
                let startTime = DispatchTime.now().rawValue
                let record = dataQueue[count]
                await MainActor.run(body: {
                    print("topic: \(record.topic) key: \(record.key) value: \(record.value)")
                    if carSpecific.contains(record.topic) {
                        addCarSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    } else if sessionSpecific.contains(record.topic) {
                        addSessionSpecificData(topic: record.topic, key: record.key, value: record.value)
                    } else {
                        addLapSpecificData(topic: record.topic, driver: record.key, value: record.value)
                    }

                })
                let processingDelay = DispatchTime.now().rawValue - startTime
                
                if count < (dataQueue.count - 1) {
                    let delay = ((dataQueue[count + 1].timestamp - dataQueue[count].timestamp) * Double(NSEC_PER_SEC)) - Double(processingDelay)
                    if delay > 0 {
                        do {
                            //try await Task.sleep(nanoseconds: UInt64(delay))
                        }
                        catch {
                            return
                        }
                    }
                    //dataQueue.remove(at: count)
                    count += 1
                } else {
                    if sessionDatabase.EndTime != "" {
                        return
                    } else {
                        /*
                        If this condition is reached and it is not the last message for the session, retrieving of messages from Kafka
                        is slower than the delay behind the live stream. TODO: Handle this case by notifying user about slow network.
                        */
                        return
                    }
                }
                
            }
        }
    }
    
}
