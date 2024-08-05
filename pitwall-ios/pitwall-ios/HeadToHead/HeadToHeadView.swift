//
//  HeadToHeadView.swift
//  pitwall-ios
//
//  Created by Robin on 31/8/23.
//

import SwiftUI

struct HeadToHeadView: View {
    
    @EnvironmentObject var processor: DataProcessor
    let viewModel: HeadToHeadViewModel
    @State private var viewModels: (SpeedTraceViewModel, TrackDominanceViewModel, LapSimulationViewModel)?
    
    var body: some View {
        if viewModels != nil {
            comparisonView
        } else {
            selectorView
        }
    }
    
    @ViewBuilder
    var comparisonView: some View {
        if let viewModels = viewModels {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(radius: 10)
                
                VStack(alignment: .leading) {
                    Text("Head To Head")
                        .font(.title)
                        .foregroundStyle(.black)
                        .fontWeight(.heavy)
                        .padding(.leading)
                        .padding(.top)
                    
                    lapInfoView
                    
                    Text("Speed Trace")
                        .padding(.leading)
                        .padding(.top)
                        .fontWeight(.heavy)
                        .font(.body)
                    SpeedTraceView(processor: _processor, viewModel: viewModels.0)
                        .padding()
                        .frame(height: 350)
                    Text("Track Dominance")
                        .padding(.leading)
                        .fontWeight(.heavy)
                        .font(.body)
                    TrackDominanceView(viewModel: viewModels.1)
                        .padding()
                        .frame(height: 250)
                    Text("Lap Simulation")
                        .padding(.leading)
                        .fontWeight(.heavy)
                        .font(.body)
                    LapSimulationView(processor: _processor, viewModel: viewModels.2)
                        .padding()
                        .frame(height: 350)
                }
            }
            .frame(maxHeight: .infinity)
            .padding()
        }
    }
    
    var lapInfoView: some View {
        HStack {
            VStack(spacing: 0) {
                // Set column heading
                Text("Driver")
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                    .font(.headline)
                ForEach(0..<selections.count, id: \.self) { j in
                    let drvInfo = (processor.driverInfo.lookup[selections[j].name]?.sName ?? "") + " L" + "\(selections[j].lap)"
                    Text(drvInfo)
                        .padding(.trailing, 8)
                        .padding(.vertical, 8)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                lapInfoSubView
            }
        }.padding(.horizontal)
    }
    
    var lapInfoSubView: some View {
        HStack(spacing: 0) {
            let headers = ["Lap Time", "Tyre", "Sector 1", "Sector 2", "Sector 3"]
            ForEach(0..<headers.count, id: \.self) { i in
                VStack(spacing: 0) {
                    Text("\(headers[i])")
                        .padding(8)
                        .font(.headline)
                        .foregroundColor(Color.black)
                    
                    ForEach(0..<selections.count, id: \.self) { j in
                        let driverObject = processor.driverDatabase[selections[j].name]?.laps[String(selections[j].lap)]
                        if let driverObject = driverObject {
                            HStack(spacing: 0) {
                                switch headers[i] {
                                case "Lap Time":
                                    Text(driverObject.LapTime.value)
                                        .padding(8)
                                    
                                case "Tyre":
                                    Text(driverObject.TyreType.value +  " " + String(driverObject.TyreAge.value))
                                        .padding(8)
                                    
                                case "Sector 1":
                                    let sector = convertLapTimeToSeconds(time: driverObject.Sector1Time.value)
                                    Text("\(driverObject.Sector1Time.value)")
                                        .foregroundColor(sector.isNearlyEqual(to: processor.sessionDatabase.FastestSector1) ? Color.white : Color.black)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(sector.isNearlyEqual(to: processor.sessionDatabase.FastestSector1) ? Color.purple : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                case "Sector 2":
                                    let sector = convertLapTimeToSeconds(time: driverObject.Sector2Time.value)
                                    Text("\(driverObject.Sector2Time.value)")
                                        .foregroundColor(sector.isNearlyEqual(to: processor.sessionDatabase.FastestSector1) ? Color.white : Color.black)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(sector.isNearlyEqual(to: processor.sessionDatabase.FastestSector2) ? Color.purple : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                case "Sector 3":
                                    let sector = convertLapTimeToSeconds(time: driverObject.Sector3Time.value)
                                    Text("\(driverObject.Sector3Time.value)")
                                        .foregroundColor(sector.isNearlyEqual(to: processor.sessionDatabase.FastestSector1) ? Color.white : Color.black)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(sector.isNearlyEqual(to: processor.sessionDatabase.FastestSector3) ? Color.purple : nil)
                                        .cornerRadius(15)
                                        .padding(.vertical, 6)
                                default:
                                    Text("")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    @State private var selectedDriver: String = ""
    @State private var selectedLap: String = ""
    @State private var selections = [selection]()
    
    private struct selection: Hashable {
        let id: String
        let name: String
        let lap: Int
    }
    
    var selectorView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(radius: 10)
            
            VStack(alignment: .leading) {
                Text("Head To Head")
                    .font(.title)
                    .foregroundStyle(.black)
                    .fontWeight(.heavy)
                    .padding(.leading)
                    .padding(.top)
                
                Text("Select up to 5 laps to compare side-by-side")
                    .padding(.leading)
                    .foregroundStyle(.black)
                    .font(.caption)
                
                HStack {
                    Picker("Select a driver", selection: $selectedDriver) {
                        ForEach(processor.driverList, id: \.self) { num in
                            Text(processor.driverInfo.lookup[num]?.sName ?? "")
                                .foregroundStyle(.black)
                        }
                    }
                    .pickerStyle(.inline)
                    .frame(height: 100)
                    
                    Picker("Select a lap", selection: $selectedLap) {
                        // TODO: Sort as int instead of string
                        ForEach(Array(processor.driverDatabase[selectedDriver]?.laps.keys ?? ["1": Lap(TyreType: ("", 0))].keys).sorted(), id: \.self) { key in
                            Text(key)
                                .foregroundStyle(.black)
                        }
                    }
                    .pickerStyle(.inline)
                    .frame(height: 100)
                }.onAppear {
                    selectedDriver = processor.driverList.first ?? "1"
                }
                
                HStack {
                    Spacer()
                    Button("Add to comparison") {
                        
                        if selections.count == 5 {
                            // TODO: Prompt user to avoid
                            return
                        }
                        
                        if !selections.contains(where: {$0.id == selectedDriver + selectedLap}) {
                            selections.append(selection(id: selectedDriver + selectedLap, name: selectedDriver, lap: Int(selectedLap) ?? 1))
                        } else {
                            // TODO: Prompt user to avoid repitition
                        }
                    }
                    .padding()
                    .foregroundStyle(.white)
                    .background(Color(red: 0, green: 0, blue: 0.5))
                    .clipShape(Capsule())
                    Spacer()
                }.padding()
                
                if !selections.isEmpty {
                    Text("Selected Laps")
                        .padding()
                        .font(.body)
                        .fontWeight(.heavy)
                    List($selections, id: \.self, editActions: .delete) { $selection in
                        let sel = (processor.driverInfo.lookup[selection.name]?.sName ?? "") + " L" + "\(selection.lap)"
                        Text(sel)
                    }
                    .padding(.horizontal)
                    .cornerRadius(10)
                    .frame(height: 150)
                    
                    HStack {
                        Spacer()
                        Button("Compare") {
                            
                            if selections.count < 2 {
                                // TODO: Prompt user to avoid
                                return
                            }
                            
                            Task.detached(priority: .userInitiated) {
                                var drivers = [String]()
                                var laps = [Int]()
                                
                                for sel in await self.selections {
                                    drivers.append(sel.name)
                                    laps.append(sel.lap)
                                }
                                
                                let viewModelsInternal = viewModel.load(drivers: drivers, laps: laps)
                                
                                await MainActor.run(body: {
                                    viewModels = viewModelsInternal
                                })
                            }
                        }
                        .padding()
                        .foregroundStyle(.white)
                        .background(Color(red: 0, green: 0, blue: 0.5))
                        .clipShape(Capsule())
                        Spacer()
                    }.padding()
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
}
