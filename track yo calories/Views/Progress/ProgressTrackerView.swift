//
//  ProgressTrackerView.swift
//  track yo calories
//

import SwiftUI
import Charts

struct ProgressTrackerView: View {
    @ObservedObject var dataStore: DataStore
    @State private var showWeightLogSheet: Bool = false
    @State private var selectedTimeRange: TimeRange = .all
    @State private var showBackfillPrompt: Bool = false
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneWeek = "7D"
        case oneMonth = "1M"
        case threeMonths = "3M"
        case all = "All"
        
        var id: String { rawValue }
        
        var dayCount: Int? {
            switch self {
            case .oneWeek: return 7
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .all: return nil
            }
        }
    }
    
    var unitSystem: UnitSystem {
        dataStore.userProfile.unitSystem
    }
    
    var allSortedWeightEntries: [WeightEntry] {
        dataStore.weightEntries.sorted(by: { $0.date < $1.date })
    }
    
    var filteredWeightEntries: [WeightEntry] {
        guard let days = selectedTimeRange.dayCount else {
            return allSortedWeightEntries
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = allSortedWeightEntries.filter { $0.date >= cutoff }
        return filtered.isEmpty ? allSortedWeightEntries : filtered
    }
    
    var currentWeightKg: Double {
        allSortedWeightEntries.last?.weightKg ?? dataStore.userProfile.weightKg
    }
    
    var startingWeightKg: Double {
        allSortedWeightEntries.first?.weightKg ?? dataStore.userProfile.weightKg
    }
    
    var targetWeightKg: Double {
        dataStore.userProfile.targetWeightKg
    }
    
    var weightChangeKg: Double {
        currentWeightKg - startingWeightKg
    }
    
    var remainingToTargetKg: Double {
        abs(currentWeightKg - targetWeightKg)
    }
    
    var currentBMI: Double {
        NutritionEngine.calculateBMI(
            weightKg: currentWeightKg,
            heightCm: dataStore.userProfile.heightCm
        )
    }
    
    // Dynamic X-Scale domain so sparse entries never collapse
    private var chartXDomain: ClosedRange<Date> {
        let dates = filteredWeightEntries.map { $0.date }
        let minDate = dates.min() ?? Date().addingTimeInterval(-86400 * 7)
        let maxDate = dates.max() ?? Date()
        
        let cal = Calendar.current
        if cal.isDate(minDate, inSameDayAs: maxDate) {
            let start = cal.date(byAdding: .day, value: -3, to: minDate) ?? minDate
            let end = cal.date(byAdding: .day, value: 1, to: maxDate) ?? maxDate
            return start...end
        }
        let start = cal.date(byAdding: .day, value: -1, to: minDate) ?? minDate
        let end = cal.date(byAdding: .day, value: 1, to: maxDate) ?? maxDate
        return start...end
    }
    
    // Dynamic Y-Scale domain with padding
    private var chartYDomain: ClosedRange<Double> {
        let values = (filteredWeightEntries.map { unitSystem.kgToDisplay($0.weightKg) } + [unitSystem.kgToDisplay(targetWeightKg)])
        let minVal = values.min() ?? 60.0
        let maxVal = values.max() ?? 80.0
        let padding = max(2.0, (maxVal - minVal) * 0.25)
        return (minVal - padding)...(maxVal + padding)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Current Weight Summary Card
                    VStack(spacing: 16) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Weight")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.1f", unitSystem.kgToDisplay(currentWeightKg)))
                                        .font(.system(size: 38, weight: .bold, design: .rounded))
                                    
                                    Text(unitSystem.weightUnit)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Target Goal")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                Text("\(String(format: "%.1f", unitSystem.kgToDisplay(targetWeightKg))) \(unitSystem.weightUnit)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Divider()
                        
                        // 3 Progress Stats
                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("\(String(format: "%.1f", unitSystem.kgToDisplay(startingWeightKg))) \(unitSystem.weightUnit)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("Start")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(spacing: 2) {
                                let changeDisplay = unitSystem.kgToDisplay(weightChangeKg)
                                let prefix = changeDisplay > 0 ? "+" : ""
                                Text("\(prefix)\(String(format: "%.1f", changeDisplay)) \(unitSystem.weightUnit)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(weightChangeKg <= 0 ? .green : .orange)
                                Text("Total Change")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(spacing: 2) {
                                Text("\(String(format: "%.1f", unitSystem.kgToDisplay(remainingToTargetKg))) \(unitSystem.weightUnit)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("To Target")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Weight Trend Graph Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Weight Trend")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            
                            Spacer()
                            
                            Button(action: { showWeightLogSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Log Weight")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Time Range Selector
                        Picker("Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Swift Charts Graph
                        if !filteredWeightEntries.isEmpty {
                            Chart {
                                // Shaded Area Gradient
                                ForEach(filteredWeightEntries) { entry in
                                    AreaMark(
                                        x: .value("Date", entry.date),
                                        yStart: .value("Min", chartYDomain.lowerBound),
                                        yEnd: .value("Weight", unitSystem.kgToDisplay(entry.weightKg))
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.35), Color.orange.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.monotone)
                                }
                                
                                // Connected Trend Line
                                ForEach(filteredWeightEntries) { entry in
                                    LineMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Weight", unitSystem.kgToDisplay(entry.weightKg))
                                    )
                                    .interpolationMethod(.monotone)
                                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .foregroundStyle(Color.orange)
                                    
                                    PointMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Weight", unitSystem.kgToDisplay(entry.weightKg))
                                    )
                                    .symbolSize(50)
                                    .foregroundStyle(Color.orange)
                                }
                                
                                // Target Goal Line
                                RuleMark(y: .value("Target", unitSystem.kgToDisplay(targetWeightKg)))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                    .foregroundStyle(Color.green)
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text("Goal: \(Int(unitSystem.kgToDisplay(targetWeightKg)))\(unitSystem.weightUnit)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 4)
                                            .background(Color(.secondarySystemGroupedBackground))
                                            .cornerRadius(4)
                                    }
                            }
                            .frame(height: 200)
                            .chartXScale(domain: chartXDomain)
                            .chartYScale(domain: chartYDomain)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                    AxisGridLine()
                                }
                            }
                        }
                        
                        // Helpful Prompt when only 1 entry is logged
                        if allSortedWeightEntries.count <= 1 {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("You have 1 weigh-in logged.")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                
                                Text("Log weights on past or future dates with '+ Log Weight' to draw your multi-day trend line.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(12)
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // BMI Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Body Mass Index (BMI)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "%.1f", currentBMI))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        
                        Spacer()
                        
                        Text(NutritionEngine.bmiCategory(bmi: currentBMI))
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Weight History Log List
                    if !allSortedWeightEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Weight History")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Spacer()
                                Text("\(allSortedWeightEntries.count) weigh-ins")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(allSortedWeightEntries.reversed()) { entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            if let notes = entry.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(String(format: "%.1f", unitSystem.kgToDisplay(entry.weightKg))) \(unitSystem.weightUnit)")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(.orange)
                                        
                                        Button(action: {
                                            withAnimation {
                                                dataStore.deleteWeightEntry(id: entry.id)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                                .foregroundColor(.red.opacity(0.8))
                                                .padding(6)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Progress")
            .sheet(isPresented: $showWeightLogSheet) {
                WeightLogSheet(dataStore: dataStore)
            }
        }
    }
}
