//
//  DriverView.swift
//  pitwall-ios
//
//  Created by Robin on 7/8/24.
//

import SwiftUI

struct DriverView: View {
    
    @EnvironmentObject var processor: DataProcessor

    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            LazyHStack {
//                ForEach(0..<processor.driverList.count, id: \.self) { i in
                    VStack(alignment: .leading) {
                        let driverObject = processor.driverDatabase[processor.driverList[5]]
                        if driverObject != nil {
                            let drvName = processor.driverInfo.lookup[processor.driverList[5]]?.fName ?? ""
                            Text(drvName)
                                .font(.title)
                                .fontWeight(.heavy)
                                .padding(.leading)
                                .padding(.top)
                            
                            CarDataView(driver: processor.driverList[5])
                                .padding()
                         
                            ScrollView(.vertical, showsIndicators: true) {
                                LapHistoryView(driver: processor.driverList[5])
                            }
                            .frame(maxHeight: 250)
                            .padding()
                            
                            Text("Gap to leader")
                                .font(.body)
                                .fontWeight(.heavy)
                                .padding()
                            
                            GapOrIntervalView(driver: processor.driverList[5], type: "GAP")
                            
                            Text("Interval to position ahead")
                                .font(.body)
                                .fontWeight(.heavy)
                                .padding()
                            
                            GapOrIntervalView(driver: processor.driverList[5], type: "INT")
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white)
                            .shadow(radius: 10)
                    }
                    .padding()
//                    .frame(width: UIScreen.main.bounds.width)
//                    .fixedSize(horizontal: true, vertical: false)
                }
//            }
//        }
//    }
}
