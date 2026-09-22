//
//  track_yo_caloriesApp.swift
//  track yo calories
//

import SwiftUI

@main
struct track_yo_caloriesApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Keeps the Lock Screen widget current (e.g. after midnight or a restore).
            if phase == .active || phase == .background {
                DataStore.shared.updateWidgetData()
            }
        }
    }
}
