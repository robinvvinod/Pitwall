//
//  CarDataView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI

struct CarDataView: View {
    
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
                            .frame(width: 25, height: CGFloat(processor.driverDatabase["14"]!.Throttle))
                        
                    }
                    Text("\(processor.driverDatabase["14"]!.Throttle)")
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
                            .trim(from: 0, to: processor.driverDatabase["14"]!.Brake == 100 ? 1 : 0)
                            .fill(Color.red)
                            .frame(width: 25, height: 100)
                        
                    }
                    Text("\(processor.driverDatabase["14"]!.Brake)")
                        .font(.caption)
                }
            }
            
            VStack(spacing: 0) {
                
                Text("\(processor.driverDatabase["14"]!.Speed)")
                    .font(.title3)
               
                Text("\(processor.driverDatabase["14"]!.RPM)")
                    .font(.title3)
                
                Text("\(processor.driverDatabase["14"]!.Gear)")
                    .font(.title3)
                
                RoundedRectangle(cornerRadius: 25)
                    .fill(processor.driverDatabase["14"]!.DRS >= 10 ? Color.green : Color.green.opacity(0.2))
                    .frame(width: 50, height: 20)
                    .overlay(
                        Text("DRS")
                            .foregroundColor(processor.driverDatabase["14"]!.DRS >= 10 ? Color.white : Color.white.opacity(0.2))
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

//struct CarDataView_Previews: PreviewProvider {
//    static var previews: some View {
//        CarDataView()
//    }
//}
