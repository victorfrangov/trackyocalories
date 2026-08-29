//
//  WaterTrackerView.swift
//  track yo calories
//

import SwiftUI

struct WaterTrackerView: View {
    @ObservedObject var dataStore: DataStore
    @State private var showCustomWaterSheet: Bool = false
    @State private var customAmountText: String = ""
    
    var currentWaterMl: Double {
        dataStore.waterIntake(for: dataStore.selectedDate)
    }
    
    var goalMl: Double {
        dataStore.userProfile.waterGoalMl
    }
    
    var progress: Double {
        guard goalMl > 0 else { return 0 }
        return min(1.0, currentWaterMl / goalMl)
    }
    
    var unitSystem: UnitSystem {
        dataStore.userProfile.unitSystem
    }
    
    var displayCurrent: String {
        let val = unitSystem.mlToDisplay(currentWaterMl)
        return unitSystem == .metric ? "\(Int(val)) ml" : String(format: "%.1f fl oz", val)
    }
    
    var displayGoal: String {
        let val = unitSystem.mlToDisplay(goalMl)
        return unitSystem == .metric ? "\(Int(val)) ml" : String(format: "%.1f fl oz", val)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    
                    Text("Hydration")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Text("\(displayCurrent) / \(displayGoal)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.blue.opacity(0.15))
                        .frame(height: 10)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progress), height: 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 10)
            
            // Quick Add Buttons
            HStack(spacing: 10) {
                Button(action: { logWater(ml: 250) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(unitSystem == .metric ? "250 ml" : "8.5 oz")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { logWater(ml: 500) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(unitSystem == .metric ? "500 ml" : "17 oz")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { showCustomWaterSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12, weight: .bold))
                        Text("Custom")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .sheet(isPresented: $showCustomWaterSheet) {
            NavigationStack {
                Form {
                    Section("Log Water Amount (\(unitSystem.liquidUnit))") {
                        TextField(unitSystem == .metric ? "Amount in ml (e.g. 350)" : "Amount in fl oz (e.g. 12)", text: $customAmountText)
                            .keyboardType(.decimalPad)
                    }
                }
                .navigationTitle("Log Water")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCustomWaterSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if let val = Double(customAmountText), val > 0 {
                                let ml = unitSystem.displayToMl(val)
                                logWater(ml: ml)
                            }
                            customAmountText = ""
                            showCustomWaterSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.35)])
        }
    }
    
    private func logWater(ml: Double) {
        dataStore.logWater(amountMl: ml, date: dataStore.selectedDate)
    }
}
