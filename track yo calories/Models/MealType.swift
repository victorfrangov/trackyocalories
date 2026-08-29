//
//  MealType.swift
//  track yo calories
//

import SwiftUI

enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snacks
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snacks: return "Snacks"
        }
    }
    
    var iconName: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snacks: return "cup.and.saucer.fill"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .breakfast: return Color.orange
        case .lunch: return Color.yellow
        case .dinner: return Color.indigo
        case .snacks: return Color.teal
        }
    }
    
    var defaultPercentage: Double {
        switch self {
        case .breakfast: return 0.25
        case .lunch: return 0.35
        case .dinner: return 0.30
        case .snacks: return 0.10
        }
    }
}
