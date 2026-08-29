//
//  OnboardingView.swift
//  track yo calories
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var dataStore: DataStore
    @State private var currentStep: Int = 1
    
    // Step 1 State
    @State private var name: String = ""
    
    // Step 2 State
    @State private var gender: Gender = .male
    @State private var age: Int = 26
    @State private var heightDisplay: Double = 178.0
    @State private var weightDisplay: Double = 75.0
    @State private var unitSystem: UnitSystem = .metric
    
    // Step 3 State
    @State private var goal: Goal = .fatLoss
    @State private var targetWeightDisplay: Double = 70.0
    @State private var weeklyRateKg: Double = -0.5
    
    // Step 4 State
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    
    // Step 5 State
    @State private var dietType: DietType = .highProtein
    
    var tempProfile: UserProfile {
        UserProfile(
            id: UUID(),
            isOnboarded: false,
            name: name.isEmpty ? "User" : name,
            age: age,
            gender: gender,
            heightCm: unitSystem.displayToCm(heightDisplay),
            weightKg: unitSystem.displayToKg(weightDisplay),
            targetWeightKg: unitSystem.displayToKg(targetWeightDisplay),
            weeklyChangeKg: weeklyRateKg,
            activityLevel: activityLevel,
            goal: goal,
            dietType: dietType,
            unitSystem: unitSystem
        )
    }
    
    var calculatedTargets: MacroTargets {
        NutritionEngine.calculateMacroTargets(profile: tempProfile)
    }
    
    var tdee: Double {
        NutritionEngine.calculateTDEE(profile: tempProfile)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: Double(currentStep), total: 5.0)
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 1: step1Welcome
                        case 2: step2BodyMetrics
                        case 3: step3Goal
                        case 4: step4Activity
                        case 5: step5NutritionPlan
                        default: EmptyView()
                        }
                    }
                    .padding(24)
                }
                
                // Bottom Button Bar
                VStack {
                    Divider()
                    HStack(spacing: 16) {
                        if currentStep > 1 {
                            Button("Back") {
                                withAnimation { currentStep -= 1 }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 80)
                        }
                        
                        Button(action: nextStep) {
                            Text(currentStep == 5 ? "Start Tracking" : "Continue")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Setup Your Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Step 1: Welcome
    @ViewBuilder
    private var step1Welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)
                .padding(.top, 20)
            
            Text("Track Yo Calories")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("Precision macro tracking and calorie calculation tailored to your body and fitness goals.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Your name or nickname", text: $name)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            .padding(.top, 24)
        }
    }
    
    // MARK: - Step 2: Body Metrics
    @ViewBuilder
    private var step2BodyMetrics: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About You")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Picker("Unit System", selection: $unitSystem) {
                ForEach(UnitSystem.allCases) { u in
                    Text(u.rawValue).tag(u)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: unitSystem) { _, newSystem in
                if newSystem == .imperial {
                    heightDisplay = 70.0 // inches
                    weightDisplay = 165.0 // lbs
                    targetWeightDisplay = 158.0
                } else {
                    heightDisplay = 178.0 // cm
                    weightDisplay = 75.0 // kg
                    targetWeightDisplay = 72.0
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Biological Sex")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Age: \(age) years")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Stepper("Age: \(age)", value: $age, in: 14...100)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Height (\(unitSystem.heightUnit))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Height", value: $heightDisplay, format: .number)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Weight (\(unitSystem.weightUnit))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Weight", value: $weightDisplay, format: .number)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Step 3: Goal
    @ViewBuilder
    private var step3Goal: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's your primary goal?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            VStack(spacing: 12) {
                ForEach(Goal.allCases) { g in
                    Button(action: {
                        goal = g
                        weeklyRateKg = g.defaultWeeklyChangeKg
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(g.rawValue)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(g == .fatLoss ? "Caloric deficit to burn fat" : (g == .muscleGain ? "Caloric surplus with high protein" : "Maintain current weight"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if goal == g {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(goal == g ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Weight (\(unitSystem.weightUnit))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Target Weight", value: $targetWeightDisplay, format: .number)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Step 4: Activity Level
    @ViewBuilder
    private var step4Activity: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How active are you?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            VStack(spacing: 12) {
                ForEach(ActivityLevel.allCases) { act in
                    Button(action: { activityLevel = act }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(act.rawValue)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(act.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if activityLevel == act {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(activityLevel == act ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Step 5: Nutrition Plan & Diet
    @ViewBuilder
    private var step5NutritionPlan: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your Personalized Plan")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            // Diet Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Diet Strategy")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Picker("Diet", selection: $dietType) {
                    ForEach([DietType.highProtein, DietType.balanced, DietType.lowCarb, DietType.keto]) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Big Target Card
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(Int(calculatedTargets.calories))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("DAILY CALORIE TARGET")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    MacroCard(name: "Protein", grams: calculatedTargets.proteinGrams, color: .orange)
                    MacroCard(name: "Carbs", grams: calculatedTargets.carbsGrams, color: .blue)
                    MacroCard(name: "Fat", grams: calculatedTargets.fatGrams, color: .purple)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(18)
            
            // Calculation breakdown
            VStack(alignment: .leading, spacing: 6) {
                Text("Calculated using Mifflin-St Jeor equation:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Daily Burn (TDEE)")
                    Spacer()
                    Text("\(Int(tdee)) kcal")
                        .bold()
                }
                .font(.system(size: 14))
                
                HStack {
                    Text("Goal Adjustment")
                    Spacer()
                    let diff = calculatedTargets.calories - tdee
                    Text("\(diff > 0 ? "+" : "")\(Int(diff)) kcal")
                        .foregroundColor(diff < 0 ? .orange : .green)
                        .bold()
                }
                .font(.system(size: 14))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    private func nextStep() {
        if currentStep < 5 {
            withAnimation { currentStep += 1 }
        } else {
            // Save completed onboarding profile
            var profile = tempProfile
            profile.isOnboarded = true
            dataStore.userProfile = profile
            
            // Save initial weight log
            dataStore.logWeight(
                weightKg: profile.weightKg,
                date: Date()
            )
        }
    }
}
