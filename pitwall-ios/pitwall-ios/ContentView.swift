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
    
    var consumerGroup = "rest_test_32"
    var consumerID = "swift-test130"
    
    var body: some View {
        Button("HTTP") {
            Task {
                do {
                    try await createConsumer(url: "http://localhost:8082/consumers/\(consumerGroup)", name: consumerID)
                } catch {
                    print(error)
                }
                
                do {
                    try await subscribeConsumer(url: "http://localhost:8082/consumers/\(consumerGroup)/instances/\(consumerID)/subscription", topics: ["TyreAge"])
                } catch {
                    print(error)
                }

                do {
                    try await consumeRecord(url: "http://localhost:8082/consumers/\(consumerGroup)/instances/\(consumerID)/records", topic: "Position")
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
