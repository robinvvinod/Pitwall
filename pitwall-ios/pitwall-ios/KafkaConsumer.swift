//
//  KafkaConsumer.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import Foundation

// API Reference: https://docs.confluent.io/platform/current/kafka-rest/api.html

enum consumerError: Error {
    case alreadyExists
    case serverResponseError
    case decodeError
    case unacceptableRequest
}

func createConsumer(url: String, name: String) async throws -> Void {
    guard let url = URL(string: url) else {return}
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/vnd.kafka.v2+json", forHTTPHeaderField: "Content-Type")
    
    let json: [String: String] = ["name": name, "format": "json", "auto.offset.reset": "earliest", "consumer.request.timeout.ms": "1"]
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

func subscribeConsumer(url: String, topics: [String]) async throws -> Void {
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

func consumeRecord(url: String, topic: String) async throws -> Void {
    guard let url = URL(string: url) else {return}
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("application/vnd.kafka.json.v2+json", forHTTPHeaderField: "Accept")
    
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
        let serverResponse = (try JSONSerialization.jsonObject(with: data)) as? [Any] // Array of dicts
        print(serverResponse)
    } catch {
        throw consumerError.decodeError
    }
}
