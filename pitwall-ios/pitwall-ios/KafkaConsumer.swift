//
//  KafkaConsumer.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import Foundation

// API Reference: https://docs.confluent.io/platform/current/kafka-rest/api.html

class KafkaConsumer: DataProcessor  {
    
    var listen: Bool = true
    
    enum consumerError: Error {
        case alreadyExists
        case serverResponseError
        case decodeError
        case unacceptableRequest
        case emptyResponse
    }
        
    private func createConsumer(url: String, name: String) async throws -> () {
        guard let url = URL(string: url) else {return}
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/vnd.kafka.v2+json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: String] = ["name": name, "format": "binary", "auto.offset.reset": "earliest", "consumer.request.timeout.ms": "200"]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if (response as? HTTPURLResponse)?.statusCode == 409 {
                throw consumerError.alreadyExists
            }
            print(String(decoding: data, as: UTF8.self))
            throw consumerError.serverResponseError
        }        
    }

    private func subscribeConsumer(url: String, topics: [String]) async throws -> () {
        guard let url = URL(string: url) else {return}
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/vnd.kafka.v2+json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: [String]] = ["topics": topics]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else {
            print(String(decoding: data, as: UTF8.self))
            throw consumerError.serverResponseError
        }
    }

    private func consumeRecord(url: String) async throws -> [[String:AnyObject]] {
        guard let url = URL(string: url) else {throw URLError(.badURL)}
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/vnd.kafka.binary.v2+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if (response as? HTTPURLResponse)?.statusCode == 406 {
                throw consumerError.unacceptableRequest
            } else {
                print(String(decoding: data, as: UTF8.self))
                throw consumerError.serverResponseError
            }
        }
        
        do {
            guard let serverResponse = (try JSONSerialization.jsonObject(with: data)) as? [[String:AnyObject]] else { throw consumerError.emptyResponse }
            return serverResponse
        } catch {
            throw consumerError.decodeError
        }
    }
    
    func createAndSubscribeConsumer(kafkaURL: String, topics: [String], consumerGroup: String) async throws -> () {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for topic in topics {
                group.addTask(priority: .userInitiated) {
                    try await self.createConsumer(url: "\(kafkaURL)/consumers/\(topic)\(consumerGroup)", name: "\(topic)Consumer")
                    try await self.subscribeConsumer(url:"\(kafkaURL)/consumers/\(topic)\(consumerGroup)/instances/\(topic)Consumer/subscription", topics: ["\(topic)"])
                }
            }
            try await group.waitForAll()
        }
    }
    
    func startListening(kafkaURL: String, topics: [String], consumerGroup: String) async throws -> () {
        // TODO: Implement timeout to stop listening for new messages
        while listen {
            //print("iteration start")
            try await withThrowingTaskGroup(of: [[String:AnyObject]].self) { group in
                for topic in topics {
                    group.addTask(priority: .userInitiated) {
                        try await self.consumeRecord(url: "\(kafkaURL)/consumers/\(topic)\(consumerGroup)/instances/\(topic)Consumer/records")
                    }
                }

                for try await records in group {
                    try await addtoQueue(records: records)
                }
            }
            //print("iteration end")
        }
        print("Kafka terminated")
    }
}
