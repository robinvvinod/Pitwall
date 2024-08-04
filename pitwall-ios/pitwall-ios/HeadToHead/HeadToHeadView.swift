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
                    
                    Picker("Select a lap", selection: $selectedLap) {
                        // TODO: Sort as int instead of string
                        ForEach(Array(processor.driverDatabase[selectedDriver]?.laps.keys ?? ["1": Lap(TyreType: ("", 0))].keys).sorted(), id: \.self) { key in
                            Text(key)
                                .foregroundStyle(.black)
                        }
                    }.pickerStyle(.inline)
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
                    }.padding()
                        .foregroundStyle(.white)
                        .background(Color(red: 0, green: 0, blue: 0.5))
                        .clipShape(Capsule())
                    Spacer()
                }
                
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
                        
                        
                    }.padding()
                        .foregroundStyle(.white)
                        .background(Color(red: 0, green: 0, blue: 0.5))
                        .clipShape(Capsule())
                    Spacer()
                }
                
                
                List($selections, id: \.self, editActions: .delete) { $selection in
                    HStack {
                        Text(processor.driverInfo.lookup[selection.name]?.sName ?? "")
                        Text(String(selection.lap))
                    }
                }
                
            }
            
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
}
