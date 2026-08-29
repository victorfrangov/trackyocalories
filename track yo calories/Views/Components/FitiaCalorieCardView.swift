//
//  FitiaCalorieCardView.swift
//  track yo calories
//

import SwiftUI

struct FitiaCalorieCardView: View {
    var budgetCalories: Double
    var consumedCalories: Double
    var weeklyAverageCalories: Double
    
    var proteinConsumed: Double
    var proteinTarget: Double
    
    var carbsConsumed: Double
    var carbsTarget: Double
    
    var fatConsumed: Double
    var fatTarget: Double
    
    var onMoreOptions: () -> Void
    
    private var calorieProgress: Double {
        guard budgetCalories > 0 else { return 0 }
        return min(1.0, consumedCalories / budgetCalories)
    }
    
    private var minRangeCalories: Int {
        Int(budgetCalories * 0.9)
    }
    
    private var maxRangeCalories: Int {
        Int(budgetCalories * 1.1)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            // Top Controls: kcal (centered) | ••• (right) - Pen removed
            HStack {
                // Left spacer to keep kcal perfectly centered
                Color.clear
                    .frame(width: 28, height: 28)
                
                Spacer()
                
                Text("kcal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onMoreOptions) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary.opacity(0.8))
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 4)
            
            // Main Calorie Counter: "0 / 3,003"
            HStack(spacing: 4) {
                Text("\(Int(consumedCalories).formatted())")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("/")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text("\(Int(budgetCalories).formatted())")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            // Arched Calorie Progress Curve with Range Markers
            VStack(spacing: 6) {
                ZStack {
                    // Background Arc
                    ArchedCurveShape()
                        .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    
                    // Filled Progress Arc
                    ArchedCurveShape()
                        .trim(from: 0, to: calorieProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                }
                .frame(height: 26)
                .padding(.horizontal, 16)
                
                // Range labels
                HStack {
                    Text("\(minRangeCalories.formatted())")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(maxRangeCalories.formatted())")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 36)
            }
            
            // 3 Column Macro Section: Protein | Carbs | Fats (No text wrapping!)
            HStack(alignment: .top, spacing: 12) {
                FitiaMacroColumn(
                    title: "Protein",
                    consumed: Int(proteinConsumed),
                    target: Int(proteinTarget),
                    color: .orange
                )
                .frame(maxWidth: .infinity)
                
                FitiaMacroColumn(
                    title: "Carbs",
                    consumed: Int(carbsConsumed),
                    target: Int(carbsTarget),
                    color: .blue
                )
                .frame(maxWidth: .infinity)
                
                FitiaMacroColumn(
                    title: "Fats",
                    consumed: Int(fatConsumed),
                    target: Int(fatTarget),
                    color: .purple
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)
            
            // Weekly Average Row (Replacing End Day Button)
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Weekly Average")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(weeklyAverageCalories).formatted()) kcal / day")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(18)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
    }
}

// MARK: - Single Macro Column (Fitia Style)
struct FitiaMacroColumn: View {
    let title: String
    let consumed: Int
    let target: Int
    let color: Color
    
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(consumed) / Double(target))
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            HStack(spacing: 2) {
                Text("\(consumed)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("/")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(target)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("g")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            
            // Progress Line Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.top, 2)
        }
    }
}

// MARK: - Arched Curve Shape for Calorie Range Gauge
struct ArchedCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startPoint = CGPoint(x: rect.minX, y: rect.maxY)
        let controlPoint = CGPoint(x: rect.midX, y: rect.minY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        
        path.move(to: startPoint)
        path.addQuadCurve(to: endPoint, control: controlPoint)
        return path
    }
}
