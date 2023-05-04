//
//  ContentView.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var kafkaURL = "http://localhost:8082"
    var consumerGroup = "rest_test_53"
    var topics: [String] = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","LapCount","SessionStatus","RCM"]

    let kafka = KafkaConsumer()
    
    var body: some View {
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
