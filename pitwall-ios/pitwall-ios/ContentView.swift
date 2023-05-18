//
//  ContentView.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import SwiftUI
import Charts

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let kafkaURL = "http://192.168.1.79:8082"
    let consumerGroup = "iosapp_test_26"
    //let consumerGroup = UUID().uuidString.lowercased()
    let topics = ["TyreAge","LapTime","CurrentLap","Tyre","GapToLeader","IntervalToPositionAhead","SectorTime","Speed","InPit","NumberOfPitStops","PitOut","CarData","PositionData","Position","Retired","TotalLaps","LapCount","SessionStatus","RCM"]
    
    @StateObject var kafka = KafkaConsumer()
    @State var flag = false
    @State var tempCarData: [[Double]] = [[Double]]()
    
    var body: some View {
        VStack {
            
            //sessionInfoView
            //leaderboardView
//            TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
//                carDataView
//            }
            //carDataView
            if flag {
                speedTraceView
            }
            
            Button("Connect to Kafka") {
                Task(priority: .userInitiated) { // Starts Kafka consumer
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
                
                Task(priority: .userInitiated) { // Starts processing of messages in queue
                    /*
                     If session is over, all kafka data must be downloaded before processQueue is called.
                     Since kafka would be downloading topic by topic, items may be inserted in any position into the dataQueue array, including before the current pointer of processQueue, leading to bad memory accesses or data being missed out
                     
                     Not an issue if joining live since data would arrive in chronological order from all topics
                     
                     If joining with a delay, make sure startPoint of processQueue is >= the kafka data already downloaded
                     */
                    try await Task.sleep(for: .seconds(15))
                    kafka.listen = false
                    await kafka.processQueue()
                    print("Processing done")
                    tempCarData = addDistance(CarData: kafka.driverDatabase["14"]!.laps["15"]!.CarData)
                    flag = true
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
                        .frame(height: 150)
                        .padding()
                    
                }
                
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("UNITED STATES")
                            .padding(.leading)
                            .font(.headline)
                            .fontWeight(.heavy)
                            .padding(.bottom, 3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Miami International Autodrome")
                            .padding(.leading)
                            .fixedSize(horizontal: false, vertical: true)
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
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("05 - 07 May")
                            .padding(.bottom, 3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Sprint Shootout")
                            .padding(.bottom)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                    }.padding(.leading)
                    
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green)
                        HStack {
                            Spacer()
                            Text("LAP")
                                .font(.title2)
                                .padding(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Text("\(kafka.sessionDatabase.CurrentLap) / 57")
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
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        
        
    }
    
    var headersArray = ["Car Number", "Lap Time", "Gap", "Int", "Tyre", "Sector 1", "Sector 2", "Sector 3", "ST1", "ST2", "ST3", "Pit", "Stops", "Lap"]
    
    var leaderboardView: some View {
        
        ScrollView(.vertical, showsIndicators: true) {
            ScrollView(.horizontal, showsIndicators: false) {
                
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<headersArray.count, id: \.self) { i in
                        VStack(spacing: 0) {
                            Text("\(headersArray[i])")
                                .padding(8)
                            ForEach(0..<kafka.driverList.count, id: \.self) { j in
                                let key = kafka.driverList[j]
                                HStack(spacing: 0) {
                                    switch headersArray[i] {
                                    case "Car Number":
                                        Text(key)
                                            .foregroundColor(Color.white)
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Lap Time":
                                        Text("\(kafka.driverDatabase[key]!.LapTime)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Gap":
                                        Text("\(kafka.driverDatabase[key]!.GapToLeader)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Int":
                                        Text("\(kafka.driverDatabase[key]!.IntervalToPositionAhead)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Tyre":
                                        Text("\(kafka.driverDatabase[key]!.TyreAge) ")
                                            .padding(.vertical, 8)
                                            .padding(.leading, 8)
                                            .foregroundColor(Color.white)
                                        Text("\(kafka.driverDatabase[key]!.TyreType)")
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 8)
                                            .foregroundColor(Color.white)
                                    case "Sector 1":
                                        Text("\(kafka.driverDatabase[key]!.Sector1Time)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Sector 2":
                                        Text("\(kafka.driverDatabase[key]!.Sector2Time)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Sector 3":
                                        Text("\(kafka.driverDatabase[key]!.Sector3Time)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "ST1":
                                        Text("\(kafka.driverDatabase[key]!.Sector1SpeedTrap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "ST2":
                                        Text("\(kafka.driverDatabase[key]!.Sector2SpeedTrap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "ST3":
                                        Text("\(kafka.driverDatabase[key]!.FinishLineSpeedTrap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Pit":
                                        if kafka.driverDatabase[key]!.PitIn == false && kafka.driverDatabase[key]!.PitOut == true {
                                            Text("-")
                                                .padding(8)
                                                .foregroundColor(Color.white)
                                        } else {
                                            Text("IN")
                                                .padding(8)
                                                .foregroundColor(Color.white)
                                                .background(Color.green)
                                        }
                                    case "Stops":
                                        Text("\(kafka.driverDatabase[key]!.NumberOfPitStops)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    case "Lap":
                                        Text("\(kafka.driverDatabase[key]!.CurrentLap)")
                                            .padding(8)
                                            .foregroundColor(Color.white)
                                    default:
                                        Text("")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .background(j % 2 == 0 ? Color.gray : Color.black)
                            }
                        }
                    }
                }
            }.padding()
        }.padding(.top, 1)
    }
    
    var carDataView: some View {
                
        HStack(alignment: .top) {
        
            HStack(spacing: 0) {
                Text("Throttle")
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 20, height: 100)
                    .font(.caption)
                
                VStack {
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 25, height: 100)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 25, height: CGFloat(kafka.driverDatabase["14"]!.Throttle))
                        
                    }
                    Text("\(kafka.driverDatabase["14"]!.Throttle)")
                        .font(.caption)
                }
            }
            
            HStack(spacing: 0) {
                Text("Brake")
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 20, height: 100)
                    .font(.caption)
                
                VStack {
                    ZStack {
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 25, height: 100)
                        
                        Rectangle()
                            .trim(from: 0, to: kafka.driverDatabase["14"]!.Brake == 100 ? 1 : 0)
                            .fill(Color.red)
                            .frame(width: 25, height: 100)
                        
                    }
                    Text("\(kafka.driverDatabase["14"]!.Brake)")
                        .font(.caption)
                }
            }
            
            VStack(spacing: 0) {
                
                Text("\(kafka.driverDatabase["14"]!.Speed)")
                    .font(.title3)
               
                Text("\(kafka.driverDatabase["14"]!.RPM)")
                    .font(.title3)
                
                Text("\(kafka.driverDatabase["14"]!.Gear)")
                    .font(.title3)
                
                RoundedRectangle(cornerRadius: 25)
                    .fill(kafka.driverDatabase["14"]!.DRS >= 10 ? Color.green : Color.green.opacity(0.2))
                    .frame(width: 50, height: 20)
                    .overlay(
                        Text("DRS")
                            .foregroundColor(kafka.driverDatabase["14"]!.DRS >= 10 ? Color.white : Color.white.opacity(0.2))
                            .font(.caption)
                    )
                    .padding(.top, 5)
                
            }.frame(width: 75, height: 100)
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("KMH")
                    .font(.caption)
                Spacer()
                Text("RPM")
                    .font(.caption)
                Spacer()
                Text("GEAR")
                    .font(.caption)
                Spacer()
            }.frame(width: 35, height: 75)
                    
        }
            .frame(width: 300, height: 100)
            .padding()
    }
    
    var speedTraceView: some View {
        
        Chart {
            ForEach(tempCarData, id: \.self) { item in
                LineMark(x: .value("Distance", item[1]), y: .value("Speed", item[0]))
            }
        }
    }
    
    var positionView: some View {

        Chart {
            ForEach(Array(kafka.driverDatabase["14"]!.laps["15"]!.PositionData.enumerated()), id: \.offset) { (index,data) in
                let values = data.components(separatedBy: "::")[0].components(separatedBy: ",")
                let x = Int(values[1]) ?? 0
                let y = Int(values[2]) ?? 0
                LineMark(x: .value("X", x), y: .value("Y", y))
            }
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 14 Pro").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            
        
        ContentView().previewDevice("iPhone 14 Pro Max").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        
        ContentView().previewDevice("iPhone SE (3rd generation)").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
