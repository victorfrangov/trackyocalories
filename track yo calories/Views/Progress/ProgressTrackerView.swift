//
//  ProgressTrackerView.swift
//  track yo calories
//

import SwiftUI
import Charts

struct ProgressTrackerView: View {
    @ObservedObject var dataStore: DataStore
    @State private var showWeightLogSheet: Bool = false
    @State private var selectedTimeRange: TimeRange = .threeMonths

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case all = "All"

        var id: String { rawValue }

        var dayCount: Int? {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .all: return nil
            }
        }
    }

    private var unitSystem: UnitSystem { dataStore.userProfile.unitSystem }
    private var goal: Goal { dataStore.userProfile.goal }

    private var sortedEntries: [WeightEntry] {
        dataStore.weightEntries.sorted(by: { $0.date < $1.date })
    }

    private var chartEntries: [WeightEntry] {
        guard let days = selectedTimeRange.dayCount,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return sortedEntries
        }
        return sortedEntries.filter { $0.date >= cutoff }
    }

    private var currentKg: Double { sortedEntries.last?.weightKg ?? dataStore.userProfile.weightKg }
    private var startKg: Double { sortedEntries.first?.weightKg ?? dataStore.userProfile.weightKg }
    private var targetKg: Double { dataStore.userProfile.targetWeightKg }
    private var changeKg: Double { currentKg - startKg }

    private var bmi: Double {
        NutritionEngine.calculateBMI(weightKg: currentKg, heightCm: dataStore.userProfile.heightCm)
    }

    private func weightString(_ kg: Double, signed: Bool = false) -> String {
        let value = unitSystem.kgToDisplay(kg)
        let sign = signed && value > 0.05 ? "+" : ""
        return "\(sign)\(value.formatted(.number.precision(.fractionLength(1)))) \(unitSystem.weightUnit)"
    }

    /// Green when the change moves toward the goal.
    private func changeColor(_ deltaKg: Double) -> Color {
        guard abs(deltaKg) >= 0.05 else { return .secondary }
        switch goal {
        case .fatLoss: return deltaKg < 0 ? .green : .orange
        case .muscleGain: return deltaKg > 0 ? .green : .orange
        case .maintenance: return .secondary
        }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                chartSection

                Section {
                    HStack {
                        Text("BMI")
                        Spacer()
                        Text(bmi.formatted(.number.precision(.fractionLength(1))))
                            .monospacedDigit()
                        Text(NutritionEngine.bmiCategory(bmi: bmi))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(bmiColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(bmiColor)
                    }
                } footer: {
                    Text("BMI is a rough guide and doesn’t account for muscle mass.")
                }

                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showWeightLogSheet = true
                    } label: {
                        Label("Log Weight", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let undo = dataStore.undoAction {
                    BannerView(message: undo.message, actionTitle: "Undo") {
                        withAnimation { dataStore.undo() }
                    }
                    .task(id: undo.id) {
                        try? await Task.sleep(for: .seconds(5))
                        withAnimation { dataStore.dismissUndo(undo.id) }
                    }
                }
            }
            .sheet(isPresented: $showWeightLogSheet) {
                WeightLogSheet(dataStore: dataStore)
            }
        }
    }

    private var bmiColor: Color {
        switch bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    // MARK: - Sections
    private var summarySection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(unitSystem.kgToDisplay(currentKg).formatted(.number.precision(.fractionLength(1))))
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                    + Text(" \(unitSystem.weightUnit)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Goal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(weightString(targetKg))
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 0) {
                statColumn(weightString(startKg), "Start", .primary)
                statColumn(weightString(changeKg, signed: true), "Change", changeColor(changeKg))
                statColumn(weightString(abs(currentKg - targetKg)), "To Goal", .primary)
            }
            .padding(.vertical, 2)
        }
    }

    private func statColumn(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var chartSection: some View {
        Section("Trend") {
            Picker("Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if chartEntries.count >= 2 {
                weightChart
                    .frame(height: 200)
                    .padding(.vertical, 8)
            } else {
                ContentUnavailableView {
                    Label(chartEntries.isEmpty ? "No Weigh-ins in This Range" : "One Weigh-in So Far", systemImage: "chart.xyaxis.line")
                } description: {
                    Text("Log your weight regularly (you can back-date entries) to see your trend.")
                } actions: {
                    Button("Log Weight") { showWeightLogSheet = true }
                }
            }
        }
    }

    private var weightChart: some View {
        let values = chartEntries.map { unitSystem.kgToDisplay($0.weightKg) } + [unitSystem.kgToDisplay(targetKg)]
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = max(1.0, (maxVal - minVal) * 0.15)

        return Chart {
            ForEach(chartEntries) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", unitSystem.kgToDisplay(entry.weightKg))
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", unitSystem.kgToDisplay(entry.weightKg))
                )
                .symbolSize(30)
                .foregroundStyle(Color.accentColor)
            }

            RuleMark(y: .value("Goal", unitSystem.kgToDisplay(targetKg)))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.green)
                .annotation(position: .top, alignment: .leading) {
                    Text("Goal")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
        }
        .chartYScale(domain: (minVal - padding)...(maxVal + padding))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .accessibilityLabel("Weight trend chart")
    }

    @ViewBuilder
    private var historySection: some View {
        let entries = Array(sortedEntries.reversed())
        if !entries.isEmpty {
            Section {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let previous = index + 1 < entries.count ? entries[index + 1] : nil
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            if let notes = entry.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let previous {
                            let delta = entry.weightKg - previous.weightKg
                            Text(weightString(delta, signed: true))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(changeColor(delta))
                        }
                        Text(weightString(entry.weightKg))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .frame(minWidth: 80, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .swipeActions {
                        Button(role: .destructive) {
                            withAnimation { dataStore.deleteWeightEntry(id: entry.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("History")
            } footer: {
                Text("Swipe left on a weigh-in to delete it.")
            }
        }
    }
}
