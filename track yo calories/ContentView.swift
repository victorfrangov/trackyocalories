//
//  ContentView.swift
//  track yo calories
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataStore = DataStore.shared
    
    var body: some View {
        Group {
            if dataStore.userProfile.isOnboarded {
                MainTabView(dataStore: dataStore)
            } else {
                OnboardingView(dataStore: dataStore)
            }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
}
