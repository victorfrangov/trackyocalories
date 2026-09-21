//
//  FitiaCalorieCardView.swift
//  track yo calories
//

import SwiftUI

/// Daily calorie summary: a ring with the calories left, the goal/eaten/weekly numbers and macro progress.
struct DailySummaryView: View {
    let budget: Double
    let consumed: Double
    let weeklyAverage: Double
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    private var remaining: Double { budget - consumed }
    private var isOver: Bool { remaining < 0 }
    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(1, consumed / budget)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(isOver ? Color.red : Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    VStack(spacing: 0) {
                        Text(abs(remaining).roundedString)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(isOver ? Color.red : Color.primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(isOver ? "kcal over" : "kcal left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(width: 112, height: 112)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isOver ? "\(abs(remaining).roundedString) calories over goal" : "\(remaining.roundedString) calories left")

                VStack(alignment: .leading, spacing: 10) {
                    statRow("Goal", value: budget, icon: "target")
                    statRow("Eaten", value: consumed, icon: "fork.knife")
                    statRow("Week avg", value: weeklyAverage, icon: "chart.bar")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 14) {
                MacroProgressView(name: "Protein", consumed: protein, target: proteinTarget, color: .orange)
                MacroProgressView(name: "Carbs", consumed: carbs, target: carbsTarget, color: .blue)
                MacroProgressView(name: "Fat", consumed: fat, target: fatTarget, color: .purple)
            }
        }
        .padding(.vertical, 8)
    }

    private func statRow(_ title: String, value: Double, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.roundedString)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

struct MacroProgressView: View {
    let name: String
    let consumed: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, consumed / target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
                .tint(consumed > target * 1.1 && target > 0 ? .red : color)
            Text("\(consumed.roundedString) / \(target.roundedString) g")
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(consumed.roundedString) of \(target.roundedString) grams")
    }
}
