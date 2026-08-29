//
//  MainTabView.swift
//  track yo calories
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var dataStore: DataStore
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiaryView(dataStore: dataStore)
                .tabItem {
                    Label("Diary", systemImage: "book.pages.fill")
                }
                .tag(0)
            
            FoodSearchView(
                dataStore: dataStore,
                preselectedMeal: .breakfast,
                targetDate: dataStore.selectedDate
            )
            .tabItem {
                Label("Log Food", systemImage: "fork.knife")
            }
            .tag(1)
            
            ProgressTrackerView(dataStore: dataStore)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
            
            ProfileView(dataStore: dataStore)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
    }
}
