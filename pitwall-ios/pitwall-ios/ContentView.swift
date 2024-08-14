//
//  ContentView.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    private let kafkaURL = "http://192.168.1.79:8082"
    private let kafkaClusterID = "tCW3cjgsTqKnNnJuNQkRWA"
    private let topics = ["LapTime","CurrentLap","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","Fastest","LapCount","SessionStatus","RCM","DeletedLaps", "TyreAge", "Tyre"]
    
    @StateObject private var processor = DataProcessor(sessionType: "RACE", driverList: ["16", "1", "11", "55", "44", "14", "4", "22", "18", "81", "63", "23", "77", "2", "24", "20", "10", "21", "31", "27"]) // TODO: find a way to pass in starting order of session
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                
                SessionInfoView(country: "Azerbaijan", raceName: "Baku City Circuit", countryFlag: "🇦🇿", roundNum: "4", roundDate: "28 - 30 April", sessionName: "Race")
                
                LeaderboardView()
                
                DriverView()
                
                HeadToHeadView(viewModel: HeadToHeadViewModel(processor: processor))
                                                                                                    
                Button("Connect to kafka") {
                    
                    let kafka = KafkaConsumer(DataProcessor: processor)
                    let consumerGroup = "pitwall_ios_" + UUID().uuidString
                    
                    Task.detached(priority: .userInitiated) { // Starts processor consumer
                        do {
                            try await kafka.createAndSubscribeConsumer(kafkaURL: kafkaURL, topics: topics, consumerGroup: consumerGroup)
                        } catch {
                            guard error as? KafkaConsumer.consumerError == .alreadyExists else {
                                print(error)
                                return
                            }
                        }
                        
                        do {
                            try await kafka.startListening(kafkaURL: kafkaURL, topics: topics, consumerGroup: consumerGroup)
                        } catch {
                            print(error)
                        }
                    }
                    
                    Task.detached(priority: .low) {
                        while true {
                            try await Task.sleep(nanoseconds: UInt64(10 * Double(NSEC_PER_SEC)))
                            if try await kafka.checkTermination(kafkaURL: kafkaURL, clusterID: kafkaClusterID, topics: topics, consumerGroup: consumerGroup) {
                                kafka.listen = false
                                break
                            }
                        }
                    }
                    
                    Task.detached(priority: .low) {
                        while kafka.listen {
                            try await Task.sleep(nanoseconds: UInt64(0.05 * Double(NSEC_PER_SEC)))
                            await MainActor.run {
                                processor.objectWillChange.send()
                            }
                        }
                    }
                }
                Spacer()
            }.environmentObject(processor)
        }.padding(1)
    }
}
