//
//  CalorieWidget.swift
//  CalorieWidgetExtension
//

import WidgetKit
import SwiftUI

struct CalorieWidgetEntry: TimelineEntry {
    let date: Date
    let data: CalorieWidgetData
}

struct CalorieWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieWidgetEntry {
        CalorieWidgetEntry(date: Date(), data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieWidgetEntry) -> Void) {
        let data = context.isPreview ? .preview : CalorieWidgetData.load().asOf(Date())
        completion(CalorieWidgetEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieWidgetEntry>) -> Void) {
        let now = Date()
        let stored = CalorieWidgetData.load()
        var entries = [CalorieWidgetEntry(date: now, data: stored.asOf(now))]

        // A second entry at midnight resets the totals even if the app isn't opened.
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        entries.append(CalorieWidgetEntry(date: midnight, data: stored.asOf(midnight)))

        // The app reloads the widget whenever food is logged; this is just a safety refresh.
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct CalorieWidgetEntryView: View {
    var entry: CalorieWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(data: entry.data)
        case .accessoryInline:
            LockScreenInlineView(data: entry.data)
        case .systemSmall:
            HomeScreenSmallView(data: entry.data)
        case .systemMedium:
            HomeScreenMediumView(data: entry.data)
        default:
            LockScreenRectangularView(data: entry.data)
        }
    }
}

private func progress(_ consumed: Int, _ target: Int) -> Double {
    guard target > 0 else { return 0 }
    return min(1, Double(consumed) / Double(target))
}

// MARK: - Lock Screen: Rectangular (ring + P/C/F)
struct LockScreenRectangularView: View {
    let data: CalorieWidgetData

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.3), lineWidth: 4.5)
                Circle()
                    .trim(from: 0, to: progress(data.caloriesConsumed, data.calorieBudget))
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -1) {
                    Text("\(data.caloriesConsumed)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("kcal")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 48, height: 48)

            VStack(spacing: 3.5) {
                LockScreenMacroRow(label: "P", consumed: data.proteinConsumed, target: data.proteinTarget)
                LockScreenMacroRow(label: "C", consumed: data.carbsConsumed, target: data.carbsTarget)
                LockScreenMacroRow(label: "F", consumed: data.fatConsumed, target: data.fatTarget)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(data.caloriesConsumed) of \(data.calorieBudget) calories. Protein \(data.proteinConsumed) grams, carbs \(data.carbsConsumed) grams, fat \(data.fatConsumed) grams.")
    }
}

struct LockScreenMacroRow: View {
    let label: String
    let consumed: Int
    let target: Int

    var body: some View {
        VStack(spacing: 1.5) {
            HStack {
                Text(label)
                Spacer()
                Text("\(consumed)")
            }
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.3))
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: max(0, geo.size.width * progress(consumed, target)))
                }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Lock Screen: Circular (calories left)
struct LockScreenCircularView: View {
    let data: CalorieWidgetData

    private var left: Int { data.calorieBudget - data.caloriesConsumed }

    var body: some View {
        Gauge(value: progress(data.caloriesConsumed, data.calorieBudget)) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(abs(left))")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityLabel(left >= 0 ? "\(left) calories left" : "\(-left) calories over")
    }
}

// MARK: - Lock Screen: Inline (above the clock)
struct LockScreenInlineView: View {
    let data: CalorieWidgetData

    private var left: Int { data.calorieBudget - data.caloriesConsumed }

    var body: some View {
        Label {
            Text(left >= 0 ? "\(left) kcal left · P\(data.proteinConsumed)" : "\(-left) kcal over · P\(data.proteinConsumed)")
        } icon: {
            Image(systemName: "flame.fill")
        }
    }
}

// MARK: - Home Screen: Small
struct HomeScreenSmallView: View {
    let data: CalorieWidgetData

    private var left: Int { data.calorieBudget - data.caloriesConsumed }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(data.caloriesConsumed) kcal")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(left >= 0 ? "\(left) left of \(data.calorieBudget)" : "\(-left) over \(data.calorieBudget)")
                .font(.caption)
                .foregroundStyle(left >= 0 ? Color.secondary : Color.red)

            ProgressView(value: progress(data.caloriesConsumed, data.calorieBudget))
                .tint(left >= 0 ? .orange : .red)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                MacroMiniRow(name: "P", consumed: data.proteinConsumed, target: data.proteinTarget, color: .orange)
                MacroMiniRow(name: "C", consumed: data.carbsConsumed, target: data.carbsTarget, color: .blue)
                MacroMiniRow(name: "F", consumed: data.fatConsumed, target: data.fatTarget, color: .purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Home Screen: Medium
struct HomeScreenMediumView: View {
    let data: CalorieWidgetData

    private var left: Int { data.calorieBudget - data.caloriesConsumed }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Today", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("\(abs(left))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(left >= 0 ? "kcal left" : "kcal over")
                    .font(.caption)
                    .foregroundStyle(left >= 0 ? Color.secondary : Color.red)
                Text("\(data.caloriesConsumed) of \(data.calorieBudget) eaten")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                MacroBarRow(name: "Protein", consumed: data.proteinConsumed, target: data.proteinTarget, color: .orange)
                MacroBarRow(name: "Carbs", consumed: data.carbsConsumed, target: data.carbsTarget, color: .blue)
                MacroBarRow(name: "Fat", consumed: data.fatConsumed, target: data.fatTarget, color: .purple)
            }
            .frame(maxWidth: .infinity)
        }
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
                .foregroundStyle(color)
                .frame(width: 12, alignment: .leading)
            Text("\(consumed) / \(target) g")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct MacroBarRow: View {
    let name: String
    let consumed: Int
    let target: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
                Text("\(consumed) / \(target) g")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress(consumed, target))
                .tint(color)
        }
    }
}

// MARK: - Widget
struct CalorieWidget: Widget {
    let kind: String = "CalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieWidgetProvider()) { entry in
            CalorieWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Calories & Macros")
        .description("Today’s calories and protein, carbs and fat.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
            .systemSmall,
            .systemMedium
        ])
    }
}

@main
struct CalorieWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalorieWidget()
    }
}

#Preview(as: .accessoryRectangular) {
    CalorieWidget()
} timeline: {
    CalorieWidgetEntry(date: .now, data: .preview)
}
