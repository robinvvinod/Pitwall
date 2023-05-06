//
//  ContentView.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let kafkaURL = "http://localhost:8082"
    let consumerGroup = "rest_test_115"
    let topics = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","LapCount","SessionStatus","RCM"]
    
    @ObservedObject var kafka = KafkaConsumer()
    
    var body: some View {
        VStack {
                        
            Button("Connect to Kafka") {
                Task(priority: .userInitiated) { // Starts Kafka consumer
                    do {
                        try await kafka.createAndSubscribeConsumer(kafkaURL: kafkaURL, topics: topics, consumerGroup: consumerGroup)
                    } catch {
                        guard error as? KafkaConsumer.consumerError == .alreadyExists else {
                            return
                        }
                    }
                    
                    do {
                        try await kafka.startListening(kafkaURL: kafkaURL, topics: topics, consumerGroup: consumerGroup)
                    } catch {
                        print(error)
                    }
                }
                
                Task(priority: .userInitiated) { // Starts processing of messages in queue
                    try await Task.sleep(for: .seconds(30))
                    await kafka.processQueue(startPoint: 0)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
