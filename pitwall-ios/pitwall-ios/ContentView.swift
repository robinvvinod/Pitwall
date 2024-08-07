//
//  ContentView.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let kafkaURL = "http://192.168.1.79:8082"
    let kafkaClusterID = "FATIfHyjRveUkj5wZIIfjw"
    //let consumerGroup = "pitwall_ios_"
    let topics = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","Fastest","LapCount","SessionStatus","RCM","DeletedLaps"]
    
    @StateObject var processor = DataProcessor(sessionType: "RACE", driverList: ["16", "1", "11", "55", "44", "14", "4", "22", "18", "81", "63", "23", "77", "2", "24", "20", "10", "21", "31", "27"]) // TODO: find a way to pass in starting order of session
    @State var flag = false
    
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack {
                
                SessionInfoView(country: "United States", raceName: "Miami International Autodrome", countryFlag: "🇺🇸", roundNum: "5", roundDate: "05 - 07 May", sessionName: "Sprint Race")
                
                
                LeaderboardView() // Quali or practice
                
                HeadToHeadView(viewModel: HeadToHeadViewModel(processor: processor))
                
                
                //LeaderboardView(headersArray: ["Lap Time", "Gap", "Int", "Tyre", "Stops", "Pit", "Lap"]) // Race

                //CarDataView()
                
                //GapOrIntervalView(driver: "14", type: "GAP")
                
//                LapHistoryView(driver: "14", headersArray: ["Lap Time", "Gap", "Tyre", "Sector 1", "Sector 2", "Sector 3", "ST1", "ST2", "ST3"])
                                                    
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
                    
                    Task.detached(priority: .background) {
                        while true {
                            try await Task.sleep(nanoseconds: UInt64(10 * Double(NSEC_PER_SEC)))
                            if try await kafka.checkTermination(kafkaURL: kafkaURL, clusterID: kafkaClusterID, topics: topics, consumerGroup: consumerGroup) {
                                kafka.listen = false
                                break
                            }
                        }
                    }
                    
                    Task.detached(priority: .background) {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 14 Pro").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
