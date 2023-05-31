//
//  pitwall_iosApp.swift
//  pitwall-ios
//
//  Created by Robin on 2/5/23.
//

import SwiftUI

@main
struct pitwall_iosApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            LapComparisonView()
//            ContentView()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
