//
//  SessionInfoView.swift
//  pitwall-ios
//
//  Created by Robin on 19/5/23.
//

import SwiftUI

struct SessionInfoView: View {
    
    @EnvironmentObject var processor: DataProcessor
    private var country: String
    private var raceName: String
    private var countryFlag: String
    private var roundNum: String
    private var roundDate: String
    private var sessionName: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 10)
            
            VStack(alignment: .leading, spacing: 0) {
                
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(country)")
                            .padding(.leading)
                            .font(.headline)
                            .fontWeight(.heavy)
                            .padding(.bottom, 3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("\(raceName)")
                            .padding(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    Text("\(countryFlag)")
                        .padding(.trailing)
                        .font(.largeTitle)
                }.padding(.top)
                
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Round \(roundNum)")
                            .padding(.top)
                            .padding(.bottom, 3)
                            .fontWeight(.heavy)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("\(roundDate)")
                            .padding(.bottom, 3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("\(sessionName)")
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
                            Text("\(processor.sessionDatabase.CurrentLap) / \(processor.sessionDatabase.TotalLaps)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        
                    }
                    .frame(width: 200, height: 50)
                    .padding(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    
                }.fixedSize(horizontal: false, vertical: true)
                
            }.fixedSize(horizontal: false, vertical: true)
            
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding()
    }
}
