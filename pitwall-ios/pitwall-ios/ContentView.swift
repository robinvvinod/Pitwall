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
    //let consumerGroup = "pitwall_ios_"
    let topics = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","Fastest","LapCount","SessionStatus","RCM","DeletedLaps"]
    
    @StateObject var processor = DataProcessor(sessionType: "QUALIFYING", driverList: ["16", "1", "11", "55", "44", "14", "4", "22", "18", "81", "63", "23", "77", "2", "24", "20", "10", "21", "31", "27"]) // TODO: find a way to pass in starting order of session
    @State var flag = false
    
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack {
                
                //SessionInfoView(country: "United States", raceName: "Miami International Autodrome", countryFlag: "🇺🇸", roundNum: "5", roundDate: "05 - 07 May", sessionName: "Sprint Race")
                
                
                //LeaderboardView(headersArray: ["Lap Time", "Gap", "Tyre", "Sector 1", "Sector 2", "Sector 3", "ST1", "ST2", "ST3"]) // Quali or practice
                
                
                //LeaderboardView(headersArray: ["Lap Time", "Gap", "Int", "Tyre", "Stops", "Pit", "Lap"]) // Race

                //CarDataView()
                
                //GapOrIntervalView(driver: "14", type: "GAP")
                
//                LapHistoryView(driver: "14", headersArray: ["Lap Time", "Gap", "Tyre", "Sector 1", "Sector 2", "Sector 3", "ST1", "ST2", "ST3"])
                
                
                if flag {
                    var lapSimulationViewModel = LapSimulationViewModel(processor: processor)
                    var speedTraceViewModel = SpeedTraceViewModel(processor: processor)
                    
                    HeadToHeadView(viewModel: HeadToHeadViewModel(processor: processor))
//                    LapSimulationView(viewModel: lapSimulationViewModel)
//                        .frame(height: 500)
//                    SpeedTraceView(viewModel: speedTraceViewModel)
                }
                                                    
                Button("Connect to kafka") {
                    
                    let kafka = KafkaConsumer(DataProcessor: processor)
                    let consumerGroup = "pitwall_ios_" + String(Int.random(in: 100...10000))

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
                    
                    Task.detached(priority: .userInitiated) { // Starts processing of messages in queue
                        /*
                         If session is over, all processor data must be downloaded before processQueue is called.
                         Since processor would be downloading topic by topic, items may be inserted in any position into the dataQueue array, including before the current pointer of processQueue, leading to bad memory accesses or data being missed out
                         
                         Not an issue if joining live since data would arrive in chronological order from all topics
                         
                         If joining with a delay, make sure startPoint of processQueue is >= the processor data already downloaded
                         */
                        try await Task.sleep(for: .seconds(30))
                        kafka.listen = false
                        await processor.processQueue()
                        print("Processing done")
//                        await lapSimulationViewModel.load(processor: processor, drivers: ["1", "44", "14", "18", "77"], laps: [30,30,30,30,30])
//                        await speedTraceViewModel.load(processor: processor, drivers: ["1", "44", "14", "18", "77"], laps: [30,30,30,30,30])
                        await MainActor.run(body: {
                            flag = true
                        })
                    }
                }
                
                Spacer()
                
            }.environmentObject(processor)
        }.padding(1)
    }
    
//    var positionView: some View {
//
//        Chart {
//            ForEach(Array(processor.driverDatabase["14"]!.laps["15"]!.PositionData.enumerated()), id: \.offset) { (index,data) in
//                let values = data.components(separatedBy: "::")[0].components(separatedBy: ",")
//                let x = Int(values[1]) ?? 0
//                let y = Int(values[2]) ?? 0
//                LineMark(x: .value("X", x), y: .value("Y", y))
//            }
//        }
//    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 14 Pro").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
