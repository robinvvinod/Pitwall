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
    let consumerGroup = "rest_test_70"
    let topics = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","LapCount","SessionStatus","RCM"]

    @ObservedObject var kafka = KafkaConsumer()
    
    var body: some View {
        
        Text("\(kafka.liveDatabase["TyreAge:14"] ?? "0")")
        
        Button("HTTP") {
            Task {
                
                // Create and subscribe consumers. 1 time task
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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
