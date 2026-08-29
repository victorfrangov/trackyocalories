//
//  CalorieRingView.swift
//  track yo calories
//

import SwiftUI

struct CalorieRingView: View {
    let budget: Double
    let consumed: Double
    let burned: Double
    
    var remaining: Double {
        budget - consumed + burned
    }
    
    var progress: Double {
        guard budget > 0 else { return 0 }
        return min(1.5, consumed / (budget + burned))
    }
    
    var ringColor: Color {
        if remaining < 0 {
            return .red
        } else if progress > 0.9 {
            return .green
        } else {
            return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)
                    .frame(width: 170, height: 170)
                
                // Active Progress Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, progress)))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [ringColor.opacity(0.8), ringColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 170, height: 170)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                // Center Content
                VStack(spacing: 4) {
                    Text("\(Int(abs(remaining)))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(remaining < 0 ? .red : .primary)
                    
                    Text(remaining < 0 ? "KCAL OVER" : "KCAL LEFT")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
            }
            
            // Equation Breakdown Bar
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(Int(budget))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Budget")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text("-")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 2) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Food")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text("+")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 2) {
                    Text("\(Int(burned))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)
                    Text("Burned")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
