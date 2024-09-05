//
//  DriverView.swift
//  pitwall-ios
//
//  Created by Robin on 7/8/24.
//

import SwiftUI

struct DriverView: View {
    
    @EnvironmentObject private var processor: DataProcessor
    @State private var selectedDriver: String = "1"
    @State private var gapViewModel: GapOrIntervalViewModel?
    @State private var intViewModel: GapOrIntervalViewModel?

    var body: some View {
        VStack(alignment: .leading) {
            
            Text("Driver Metrics")
                .font(.title2)
                .fontWeight(.heavy)
                .padding(.leading)
                .padding(.top)
            
            Picker("Select driver", selection: $selectedDriver) {
                ForEach(processor.driverList, id: \.self) { rNum in
                    let name = processor.driverInfo.lookup[rNum]?.fName
                    if let name {
                        Text("\(name)")
                    }
                }
            }
            .padding()
            .onAppear {
                selectedDriver = processor.driverList.first ?? "1"
                gapViewModel = GapOrIntervalViewModel(processor: processor, driver: selectedDriver, type: "GAP")
                intViewModel = GapOrIntervalViewModel(processor: processor, driver: selectedDriver, type: "INT")
                Task.detached(priority: .low) {
                    await getGapOrIntervals()
                }
            }
        
            if let gapViewModel, let intViewModel {
                
                CarDataView(driver: selectedDriver)
                    .padding()
             
                ScrollView(.vertical, showsIndicators: true) {
                    LapHistoryView(driver: selectedDriver)
                }
                .frame(maxHeight: 250)
                .padding()
                
                Text("Gap to leader")
                    .font(.body)
                    .fontWeight(.heavy)
                    .padding()
                
                GapOrIntervalView(viewModel: gapViewModel)
                
                Text("Interval to position ahead")
                    .font(.body)
                    .fontWeight(.heavy)
                    .padding()
                
                GapOrIntervalView(viewModel: intViewModel)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(radius: 10)
        }
        .padding()
        .onChange(of: selectedDriver) { _ in
            Task.detached(priority: .low) {
                await getGapOrIntervals()
            }
        }
    }
    
    private func getGapOrIntervals() {
        if let gapViewModel, let intViewModel {
            gapViewModel.driver = selectedDriver
            intViewModel.driver = selectedDriver
            gapViewModel.getGapOrInterval()
            intViewModel.getGapOrInterval()
        }
    }
}
