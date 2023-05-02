//
//  KafkaConsumer.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import Foundation

// API Reference: https://docs.confluent.io/platform/current/kafka-rest/api.html

struct consumerCreateResponse: Codable {
    let instance_id: String
    let base_uri: String
}

struct createConsumerError: Error {
    enum ErrorKind {
        case alreadyExists
        case serverResponseError
        case decodeError
    }
    
    let kind: ErrorKind
}

func createConsumer(url: String, name: String) async throws {
    guard let url = URL(string: url) else {return}
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/vnd.kafka.v2+json", forHTTPHeaderField: "Content-Type")
    
    let json: [String: String] = ["name": name, "format": "json", "auto.offset.reset": "earliest"]
    let jsonData = try? JSONSerialization.data(withJSONObject: json)
    
    urlRequest.httpBody = jsonData
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        if (response as? HTTPURLResponse)?.statusCode == 409 {
            throw createConsumerError(kind: .alreadyExists)
        }
        throw createConsumerError(kind: .serverResponseError)
    }
    
    let result: consumerCreateResponse
    
    do {
        result = try JSONDecoder().decode(consumerCreateResponse.self, from: data)
    } catch {
        throw createConsumerError(kind: .decodeError)
    }
    
    print(result)
}
