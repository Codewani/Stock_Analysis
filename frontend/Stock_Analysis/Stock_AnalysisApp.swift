//
//  Stock_AnalysisApp.swift
//  Stock_Analysis
//
//  Created by Kondwani Mwape on 3/19/26.
//

import SwiftUI

@main
struct Stock_AnalysisApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
