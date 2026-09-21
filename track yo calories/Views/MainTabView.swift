//
//  MainTabView.swift
//  track yo calories
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var dataStore: DataStore
    @State private var selectedTab: Int = {
        #if DEBUG
        // Simulator screenshots: `-screenshotTab 1`
        return UserDefaults.standard.integer(forKey: "screenshotTab")
        #else
        return 0
        #endif
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            DiaryView(dataStore: dataStore)
                .tabItem {
                    Label("Diary", systemImage: "book.pages.fill")
                }
                .tag(0)
            
            ProgressTrackerView(dataStore: dataStore)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            ProfileView(dataStore: dataStore)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(2)
        }
    }
}
