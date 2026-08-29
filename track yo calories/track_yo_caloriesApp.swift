//
//  track_yo_caloriesApp.swift
//  track yo calories
//

import SwiftUI
import WidgetKit

@main
struct track_yo_caloriesApp: App {
    init() {
        // Force iOS to register and update Lock Screen & Home Screen widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
