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
    let consumerGroup = "rest_test_120"
    let topics = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","LapCount","SessionStatus","RCM"]
    
    @ObservedObject var kafka = KafkaConsumer()
    
    var body: some View {
        VStack {
               
            sessionInfoView
            
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
                    /*
                    If session is over, all kafka data must be downloaded before processQueue is called.
                    Since kafka would be downloading topic by topic, items may be inserted in any position into the dataQueue array, including before the current pointer of processQueue, leading to bad memory accesses or data being missed out
                     
                     Not an issue if joining live since data would arrive in chronological order from all topics
                     
                     If joining with a delay, make sure startPoint of processQueue is >= the kafka data already downloaded
                     */
                    try await Task.sleep(for:.seconds(15))
                    await kafka.processQueue(startPoint: 0)
                }
            }
            
            Spacer()
            
        }
    }
    
    var sessionInfoView: some View {
        ZStack(alignment: .topLeading) {
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 10)
            
            VStack(alignment: .leading, spacing: 0) {
                
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray).opacity(0.2)
                        .frame(width: .infinity, height: 150)
                        .padding()
                    
                }
                
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("UNITED STATES")
                            .padding(.leading)
                            .font(.headline)
                            .fontWeight(.heavy)
                            .padding(.bottom, 3)
                        
                        Text("Miami International Autodrome")
                            .padding(.leading)
                    }
                    
                    Spacer()
                    Text("🇺🇸")
                        .padding(.trailing)
                        .font(.largeTitle)
                }
                
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Round 5")
                            .padding(.top)
                            .padding(.bottom, 3)
                            .fontWeight(.heavy)
                        
                        Text("05 - 07 May")
                            .padding(.bottom, 3)
                        
                        Text("Sprint Shootout")
                            .padding(.bottom)
                            .font(.headline)
                        
                    }.padding(.leading)
                    
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green)
                            .frame(width: 175, height: 50)
                        HStack {
                            Spacer()
                            Text("LAP")
                                .font(.title2)
                                .padding(.leading)
                            Spacer()
                            Text("15 / 57")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.trailing)
                            Spacer()
                        }

                    }
                        .frame(width: 200, height: 50)
                        .padding(.trailing,3)

                }
                    
            }
            
        }
            .frame(width: .infinity, height: 325, alignment: .top)
            .padding()
            
        
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 14 Pro").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            
        
        ContentView().previewDevice("iPhone 14 Pro Max").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        
        ContentView().previewDevice("iPhone SE (3rd generation)").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
