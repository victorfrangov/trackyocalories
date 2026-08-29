//
//  MealBudgetEditorView.swift
//  track yo calories
//

import SwiftUI

struct MealBudgetEditorView: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var bPct: Double
    @State private var lPct: Double
    @State private var dPct: Double
    @State private var sPct: Double
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
        let p = dataStore.userProfile
        self._bPct = State(initialValue: p.breakfastRatio * 100)
        self._lPct = State(initialValue: p.lunchRatio * 100)
        self._dPct = State(initialValue: p.dinnerRatio * 100)
        self._sPct = State(initialValue: p.snacksRatio * 100)
    }
    
    var totalPct: Double {
        bPct + lPct + dPct + sPct
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Calorie Distribution") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Breakfast")
                            Spacer()
                            Text("\(Int(bPct))%")
                                .bold()
                        }
                        Slider(value: $bPct, in: 0...60, step: 5)
                            .tint(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Lunch")
                            Spacer()
                            Text("\(Int(lPct))%")
                                .bold()
                        }
                        Slider(value: $lPct, in: 0...60, step: 5)
                            .tint(.yellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Dinner")
                            Spacer()
                            Text("\(Int(dPct))%")
                                .bold()
                        }
                        Slider(value: $dPct, in: 0...60, step: 5)
                            .tint(.indigo)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Snacks")
                            Spacer()
                            Text("\(Int(sPct))%")
                                .bold()
                        }
                        Slider(value: $sPct, in: 0...40, step: 5)
                            .tint(.teal)
                    }
                }
                
                Section {
                    HStack {
                        Text("Total Allocation")
                        Spacer()
                        Text("\(Int(totalPct))%")
                            .bold()
                            .foregroundColor(Int(totalPct) == 100 ? .green : .red)
                    }
                } footer: {
                    if Int(totalPct) != 100 {
                        Text("Please adjust sliders so the total equals 100%.")
                            .foregroundColor(.red)
                    } else {
                        Text("Meal targets in your diary will be calculated using these proportions.")
                    }
                }
            }
            .navigationTitle("Meal Calorie Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dataStore.userProfile.breakfastRatio = bPct / 100.0
                        dataStore.userProfile.lunchRatio = lPct / 100.0
                        dataStore.userProfile.dinnerRatio = dPct / 100.0
                        dataStore.userProfile.snacksRatio = sPct / 100.0
                        dismiss()
                    }
                    .disabled(Int(totalPct) != 100)
                }
            }
        }
    }
}
