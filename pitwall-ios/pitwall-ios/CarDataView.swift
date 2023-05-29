//
//  CarDataView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI

struct CarDataView: View {
    
    var driver: String
    @EnvironmentObject var processor: DataProcessor
    
    var body: some View {
                
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
                            .frame(width: 25, height: CGFloat(processor.driverDatabase[driver]?.Throttle ?? 0))
                        
                    }
                    Text("\(processor.driverDatabase[driver]?.Throttle ?? 0)")
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
                            .trim(from: 0, to: processor.driverDatabase[driver]?.Brake == 100 ? 1 : 0)
                            .fill(Color.red)
                            .frame(width: 25, height: 100)
                        
                    }
                    Text("\(processor.driverDatabase[driver]?.Brake ?? 0)")
                        .font(.caption)
                }
            }
            
            VStack(spacing: 0) {
                
                Text("\(processor.driverDatabase[driver]?.Speed ?? 0)")
                    .font(.title3)
               
                Text("\(processor.driverDatabase[driver]?.RPM ?? 0)")
                    .font(.title3)
                
                Text("\(processor.driverDatabase[driver]?.Gear ?? 0)")
                    .font(.title3)
                
                RoundedRectangle(cornerRadius: 25)
                    .fill(processor.driverDatabase[driver]?.DRS ?? 0 >= 10 ? Color.green : Color.green.opacity(0.2))
                    .frame(width: 50, height: 20)
                    .overlay(
                        Text("DRS")
                            .foregroundColor(processor.driverDatabase[driver]?.DRS ?? 0 >= 10 ? Color.white : Color.white.opacity(0.2))
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

}
