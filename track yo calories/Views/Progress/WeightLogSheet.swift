//
//  WeightLogSheet.swift
//  track yo calories
//

import SwiftUI

struct WeightLogSheet: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var date: Date = Date()
    @State private var weightText: String = ""
    @State private var bodyFatText: String = ""
    @State private var waistText: String = ""
    @State private var chestText: String = ""
    @State private var hipsText: String = ""
    @State private var notes: String = ""
    
    var unitSystem: UnitSystem {
        dataStore.userProfile.unitSystem
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Weight (\(unitSystem.weightUnit))") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Body Fat % (Optional)")
                        Spacer()
                        TextField("e.g. 15.5", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Body Measurements (\(unitSystem.heightUnit), Optional)") {
                    HStack {
                        Text("Waist")
                        Spacer()
                        TextField("0.0", text: $waistText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Chest")
                        Spacer()
                        TextField("0.0", text: $chestText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Hips")
                        Spacer()
                        TextField("0.0", text: $hipsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Notes") {
                    TextField("Morning weigh-in, post workout, etc.", text: $notes)
                }
            }
            .onAppear {
                let currentKg = dataStore.userProfile.weightKg
                let display = unitSystem.kgToDisplay(currentKg)
                weightText = String(format: "%.1f", display)
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWeightEntry()
                    }
                }
            }
        }
    }
    
    private func saveWeightEntry() {
        guard let wVal = Double(weightText), wVal > 0 else { return }
        let kg = unitSystem.displayToKg(wVal)
        let bf = Double(bodyFatText)
        let waist = Double(waistText).map { unitSystem.displayToCm($0) }
        let chest = Double(chestText).map { unitSystem.displayToCm($0) }
        let hips = Double(hipsText).map { unitSystem.displayToCm($0) }
        let note = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes
        
        dataStore.logWeight(
            weightKg: kg,
            bodyFat: bf,
            waistCm: waist,
            chestCm: chest,
            hipsCm: hips,
            notes: note,
            date: date
        )
        dismiss()
    }
}
