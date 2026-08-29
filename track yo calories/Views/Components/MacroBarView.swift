//
//  MacroBarView.swift
//  track yo calories
//

import SwiftUI

struct MacroBarView: View {
    let name: String
    let consumed: Double
    let target: Double
    let color: Color
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, consumed / target)
    }
    
    var remainingGrams: Double {
        max(0, target - consumed)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    
                    Text(name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                Text("\(Int(consumed)) / \(Int(target))g")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar Track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            
            HStack {
                Spacer()
                Text("\(Int(remainingGrams))g left")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct MacroSummaryBarView: View {
    let carbsConsumed: Double
    let carbsTarget: Double
    let proteinConsumed: Double
    let proteinTarget: Double
    let fatConsumed: Double
    let fatTarget: Double
    
    var body: some View {
        HStack(spacing: 10) {
            MacroBarView(
                name: "Protein",
                consumed: proteinConsumed,
                target: proteinTarget,
                color: Color.orange
            )
            
            MacroBarView(
                name: "Carbs",
                consumed: carbsConsumed,
                target: carbsTarget,
                color: Color.blue
            )
            
            MacroBarView(
                name: "Fat",
                consumed: fatConsumed,
                target: fatTarget,
                color: Color.purple
            )
        }
    }
}
