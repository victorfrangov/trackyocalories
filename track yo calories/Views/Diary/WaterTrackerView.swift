//
//  WaterTrackerView.swift
//  track yo calories
//

import SwiftUI

struct WaterTrackerView: View {
    @ObservedObject var dataStore: DataStore
    @State private var showCustomWaterSheet: Bool = false

    private var date: Date { dataStore.selectedDate }
    private var unitSystem: UnitSystem { dataStore.userProfile.unitSystem }
    private var currentMl: Double { dataStore.waterIntake(for: date) }
    private var goalMl: Double { dataStore.userProfile.waterGoalMl }

    private var progress: Double {
        guard goalMl > 0 else { return 0 }
        return min(1.0, currentMl / goalMl)
    }

    private func display(_ ml: Double) -> String {
        let value = unitSystem.mlToDisplay(ml)
        return unitSystem == .metric ? "\(value.roundedString) ml" : "\(value.cleanString) fl oz"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(display(currentMl))
                        .font(.body.weight(.semibold).monospacedDigit())
                    + Text(" of \(display(goalMl))")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "drop.fill").foregroundStyle(.blue)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)

            ProgressView(value: progress)
                .tint(.blue)

            HStack(spacing: 8) {
                Button {
                    withAnimation { dataStore.removeLastWater(on: date) }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28)
                }
                .disabled(currentMl <= 0)
                .accessibilityLabel("Remove last water entry")

                quickAddButton(ml: 250, imperialLabel: "8 oz")
                quickAddButton(ml: 500, imperialLabel: "16 oz")

                Button {
                    showCustomWaterSheet = true
                } label: {
                    Text("Other…")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showCustomWaterSheet) {
            CustomWaterSheet(unitSystem: unitSystem) { ml in
                dataStore.logWater(amountMl: ml, date: date)
            }
        }
    }

    private func quickAddButton(ml: Double, imperialLabel: String) -> some View {
        // Imperial buttons log round fluid-ounce amounts rather than odd conversions of 250/500 ml.
        let amount = unitSystem == .metric ? ml : unitSystem.displayToMl(ml == 250 ? 8 : 16)
        return Button {
            withAnimation { dataStore.logWater(amountMl: amount, date: date) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text("+\(unitSystem == .metric ? "\(Int(ml)) ml" : imperialLabel)")
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        }
    }
}

private struct CustomWaterSheet: View {
    let unitSystem: UnitSystem
    var onAdd: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @FocusState private var focused: Bool

    private var amount: Double? {
        guard let v = Double(userInput: amountText), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($focused)
                        Text(unitSystem.liquidUnit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amount { onAdd(unitSystem.displayToMl(amount)) }
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(220)])
    }
}
