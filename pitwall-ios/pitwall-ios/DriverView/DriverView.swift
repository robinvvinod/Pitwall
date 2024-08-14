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
            }
        
            let driverObject = processor.driverDatabase[selectedDriver]
            if driverObject != nil {
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
                
                GapOrIntervalView(driver: selectedDriver, type: "GAP")
                
                Text("Interval to position ahead")
                    .font(.body)
                    .fontWeight(.heavy)
                    .padding()
                
                GapOrIntervalView(driver: selectedDriver, type: "INT")
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(radius: 10)
        }
        .padding()
    }
}
