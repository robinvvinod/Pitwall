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

class DataProcessor: ObservableObject {
    
    @Published var liveDatabase: [String:String] = [:]
    @Published var cacheDatabase: [String:Any] = [:]
        
    func processRecord(records: [[String:AnyObject]]) async throws -> () {
        for record in records {
            let topic = record["topic"] as? String
            let key = (record["key"] as? String)?.base64Decoded()
            let value = (record["value"] as? String)?.base64Decoded()
            
            if let topic = topic, let key = key, let value = value {
                await MainActor.run(body: {
                    liveDatabase["\(topic):\(key)"] = value
                    print(liveDatabase)
                })
            } else {return}
        }
    }
}
