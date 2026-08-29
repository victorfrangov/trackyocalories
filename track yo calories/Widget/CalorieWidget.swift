//
//  CalorieWidget.swift
//  track yo calories
//

import WidgetKit
import SwiftUI

struct CalorieWidgetEntry: TimelineEntry {
    let date: Date
    let data: CalorieWidgetData
}

struct CalorieWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieWidgetEntry {
        CalorieWidgetEntry(date: Date(), data: .default)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieWidgetEntry) -> Void) {
        let current = CalorieWidgetData.load()
        completion(CalorieWidgetEntry(date: Date(), data: current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieWidgetEntry>) -> Void) {
        let current = CalorieWidgetData.load()
        let entry = CalorieWidgetEntry(date: Date(), data: current)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct CalorieWidgetEntryView: View {
    var entry: CalorieWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenExactRectangularWidgetView(data: entry.data)
        case .accessoryCircular:
            LockScreenCircularWidgetView(data: entry.data)
        case .accessoryInline:
            LockScreenInlineWidgetView(data: entry.data)
        case .systemSmall:
            HomeScreenSmallWidgetView(data: entry.data)
        case .systemMedium:
            HomeScreenMediumWidgetView(data: entry.data)
        default:
            LockScreenExactRectangularWidgetView(data: entry.data)
        }
    }
}

// MARK: - EXACT Lock Screen Rectangular Widget (Matching User Screenshot)
struct LockScreenExactRectangularWidgetView: View {
    let data: CalorieWidgetData
    
    var calProgress: Double {
        guard data.calorieBudget > 0 else { return 0 }
        return min(1.0, Double(data.caloriesConsumed) / Double(data.calorieBudget))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Left Circle Ring
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.3), lineWidth: 4.5)
                
                Circle()
                    .trim(from: 0, to: calProgress)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: -1) {
                    Text("\(data.caloriesConsumed)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.7)
                    
                    Text("kcal")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 48, height: 48)
            
            // Right Stacked P, C, F Rows
            VStack(spacing: 3.5) {
                LockScreenMacroRow(label: "P", consumed: data.proteinConsumed, target: data.proteinTarget)
                LockScreenMacroRow(label: "C", consumed: data.carbsConsumed, target: data.carbsTarget)
                LockScreenMacroRow(label: "F", consumed: data.fatConsumed, target: data.fatTarget)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LockScreenMacroRow: View {
    let label: String
    let consumed: Int
    let target: Int
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(consumed) / Double(target))
    }
    
    var body: some View {
        VStack(spacing: 1.5) {
            HStack {
                Text(label)
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                Spacer()
                Text("\(consumed)")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.3))
                        .frame(height: 2)
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 2)
                }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Lock Screen Circular Widget
struct LockScreenCircularWidgetView: View {
    let data: CalorieWidgetData
    
    var progress: Double {
        guard data.calorieBudget > 0 else { return 0 }
        return min(1.0, Double(data.caloriesConsumed) / Double(data.calorieBudget))
    }
    
    var body: some View {
        Gauge(value: progress) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(data.caloriesConsumed)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Lock Screen Inline Widget
struct LockScreenInlineWidgetView: View {
    let data: CalorieWidgetData
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(data.caloriesConsumed) kcal • P:\(data.proteinConsumed) C:\(data.carbsConsumed) F:\(data.fatConsumed)")
        }
    }
}

// MARK: - Home Screen Small Widget
struct HomeScreenSmallWidgetView: View {
    let data: CalorieWidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(data.caloriesConsumed) kcal")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            
            Text("\(max(0, data.calorieBudget - data.caloriesConsumed)) kcal left")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                MacroMiniRow(name: "P", consumed: data.proteinConsumed, target: data.proteinTarget, color: .orange)
                MacroMiniRow(name: "C", consumed: data.carbsConsumed, target: data.carbsTarget, color: .blue)
                MacroMiniRow(name: "F", consumed: data.fatConsumed, target: data.fatTarget, color: .purple)
            }
        }
        .padding()
    }
}

// MARK: - Home Screen Medium Widget
struct HomeScreenMediumWidgetView: View {
    let data: CalorieWidgetData
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Daily Nutrition")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                
                Text("\(data.caloriesConsumed)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("of \(data.calorieBudget) kcal goal")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                MacroBarWidgetRow(name: "Protein", consumed: data.proteinConsumed, target: data.proteinTarget, color: .orange)
                MacroBarWidgetRow(name: "Carbs", consumed: data.carbsConsumed, target: data.carbsTarget, color: .blue)
                MacroBarWidgetRow(name: "Fat", consumed: data.fatConsumed, target: data.fatTarget, color: .purple)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

struct MacroMiniRow: View {
    let name: String
    let consumed: Int
    let target: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(width: 14, alignment: .leading)
            
            Text("\(consumed)/\(target)g")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

struct MacroBarWidgetRow: View {
    let name: String
    let consumed: Int
    let target: Int
    let color: Color
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(consumed) / Double(target))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Spacer()
                Text("\(consumed)/\(target)g")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 5)
        }
    }
}


struct CalorieWidget: Widget {
    let kind: String = "CalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieWidgetProvider()) { entry in
            CalorieWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Daily Macros")
        .description("Track your consumed calories and P/C/F macros directly on your Lock Screen.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
            .systemSmall,
            .systemMedium
        ])
    }
}
