//
//  NutritionAnalyticsView.swift
//  track yo calories
//

import SwiftUI
import Charts

struct DailyNutritionStat: Identifiable {
    var id: String { date.formatted(date: .numeric, time: .omitted) }
    var date: Date
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var waterMl: Double
}

struct NutritionAnalyticsView: View {
    @ObservedObject var dataStore: DataStore
    @State private var selectedRange: AnalyticsRange = .last7Days
    
    enum AnalyticsRange: String, CaseIterable, Identifiable {
        case last7Days = "7 Days"
        case last14Days = "14 Days"
        case last30Days = "30 Days"
        
        var id: String { rawValue }
        
        var dayCount: Int {
            switch self {
            case .last7Days: return 7
            case .last14Days: return 14
            case .last30Days: return 30
            }
        }
    }
    
    var dailyStats: [DailyNutritionStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var stats: [DailyNutritionStat] = []
        
        for offset in (0..<selectedRange.dayCount).reversed() {
            if let d = calendar.date(byAdding: .day, value: -offset, to: today) {
                let cal = dataStore.totalCalories(for: d)
                let pro = dataStore.totalProtein(for: d)
                let carb = dataStore.totalCarbs(for: d)
                let fat = dataStore.totalFat(for: d)
                let water = dataStore.waterIntake(for: d)
                stats.append(DailyNutritionStat(date: d, calories: cal, protein: pro, carbs: carb, fat: fat, waterMl: water))
            }
        }
        return stats
    }
    
    var targetCalories: Double {
        NutritionEngine.calculateTargetCalories(profile: dataStore.userProfile)
    }
    
    var averageCalories: Double {
        let nonZero = dailyStats.filter { $0.calories > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0.0) { $0 + $1.calories } / Double(nonZero.count)
    }
    
    var averageProtein: Double {
        let nonZero = dailyStats.filter { $0.protein > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0.0) { $0 + $1.protein } / Double(nonZero.count)
    }
    
    var averageCarbs: Double {
        let nonZero = dailyStats.filter { $0.carbs > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0.0) { $0 + $1.carbs } / Double(nonZero.count)
    }
    
    var averageFat: Double {
        let nonZero = dailyStats.filter { $0.fat > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0.0) { $0 + $1.fat } / Double(nonZero.count)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedRange) {
                        ForEach(AnalyticsRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Calorie Adherence Chart
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Daily Calorie Intake")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        
                        Chart {
                            ForEach(dailyStats) { stat in
                                BarMark(
                                    x: .value("Date", stat.date, unit: .day),
                                    y: .value("Calories", stat.calories)
                                )
                                .foregroundStyle(stat.calories > targetCalories + 150 ? Color.orange : Color.accentColor)
                                .cornerRadius(4)
                            }
                            
                            RuleMark(y: .value("Target", targetCalories))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                .foregroundStyle(Color.green)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Goal: \(Int(targetCalories))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                }
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: selectedRange == .last30Days ? 5 : 1)) { _ in
                                AxisValueLabel(format: .dateTime.day())
                                AxisGridLine()
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Average Stats Grid
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Daily Averages (Active Days)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            AnalyticsMetricCard(title: "Avg Calories", value: "\(Int(averageCalories)) kcal", color: .primary)
                            AnalyticsMetricCard(title: "Avg Protein", value: "\(Int(averageProtein)) g", color: .orange)
                            AnalyticsMetricCard(title: "Avg Carbs", value: "\(Int(averageCarbs)) g", color: .blue)
                            AnalyticsMetricCard(title: "Avg Fat", value: "\(Int(averageFat)) g", color: .purple)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nutrition Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
