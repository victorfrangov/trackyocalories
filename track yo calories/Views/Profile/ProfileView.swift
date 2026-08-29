//
//  ProfileView.swift
//  track yo calories
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var dataStore: DataStore
    
    @State private var showMacroEditor: Bool = false
    @State private var showMealBudgetEditor: Bool = false
    @State private var showEditProfileSheet: Bool = false
    @State private var showApiKeySheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL? = nil
    
    var unitSystem: UnitSystem {
        dataStore.userProfile.unitSystem
    }
    
    var macroTargets: MacroTargets {
        NutritionEngine.calculateMacroTargets(profile: dataStore.userProfile)
    }
    
    var tdee: Double {
        NutritionEngine.calculateTDEE(profile: dataStore.userProfile)
    }
    
    var bmr: Double {
        NutritionEngine.calculateBMR(profile: dataStore.userProfile)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Overview Card
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dataStore.userProfile.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            
                            Text("\(dataStore.userProfile.goal.rawValue) • \(dataStore.userProfile.dietType.rawValue)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            showEditProfileSheet = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 6)
                }
                
                // Metabolic Metrics
                Section("Metabolic Calculations") {
                    HStack {
                        Text("Basal Metabolic Rate (BMR)")
                        Spacer()
                        Text("\(Int(bmr)) kcal")
                            .bold()
                    }
                    HStack {
                        Text("Total Daily Energy (TDEE)")
                        Spacer()
                        Text("\(Int(tdee)) kcal")
                            .bold()
                    }
                    HStack {
                        Text("Current Weight")
                        Spacer()
                        Text("\(String(format: "%.1f", unitSystem.kgToDisplay(dataStore.userProfile.weightKg))) \(unitSystem.weightUnit)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Weight")
                        Spacer()
                        Text("\(String(format: "%.1f", unitSystem.kgToDisplay(dataStore.userProfile.targetWeightKg))) \(unitSystem.weightUnit)")
                            .foregroundColor(.green)
                            .bold()
                    }
                }
                
                // Nutrition & Macro Goals
                Section("Nutrition & Macro Targets") {
                    Button(action: { showMacroEditor = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Daily Target: \(Int(macroTargets.calories)) kcal")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Protein: \(Int(macroTargets.proteinGrams))g • Carbs: \(Int(macroTargets.carbsGrams))g • Fat: \(Int(macroTargets.fatGrams))g")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showMealBudgetEditor = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Meal Calorie Distribution")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("B: \(Int(dataStore.userProfile.breakfastRatio * 100))% • L: \(Int(dataStore.userProfile.lunchRatio * 100))% • D: \(Int(dataStore.userProfile.dinnerRatio * 100))% • S: \(Int(dataStore.userProfile.snacksRatio * 100))%")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // AI Food Scanner (Google Gemini)
                Section("AI Food Scanner (Google Gemini)") {
                    let hasKey = dataStore.userProfile.geminiApiKey?.isEmpty == false
                    
                    Button(action: { showApiKeySheet = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Gemini Vision API Key")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text(hasKey ? "Active (Gemini 2.0 Flash - Free 1,500/day)" : "Tap to set up free API Key")
                                    .font(.system(size: 12))
                                    .foregroundColor(hasKey ? .green : .secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                        HStack {
                            Label("Get a Free Key from Google AI Studio", systemImage: "arrow.up.right.square")
                                .font(.system(size: 13))
                            Spacer()
                        }
                    }
                }
                
                // Preferences
                Section("Preferences") {
                    Picker("Unit System", selection: $dataStore.userProfile.unitSystem) {
                        ForEach(UnitSystem.allCases) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    
                    HStack {
                        Text("Daily Water Goal")
                        Spacer()
                        Text("\(Int(unitSystem.mlToDisplay(dataStore.userProfile.waterGoalMl))) \(unitSystem.liquidUnit)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Data & Backup
                Section("Data & Privacy") {
                    Button(action: exportDataJSON) {
                        Label("Export Data Backup (JSON)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: {
                        dataStore.userProfile.isOnboarded = false
                    }) {
                        Label("Re-run Onboarding Setup", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showMacroEditor) {
                MacroEditorView(dataStore: dataStore)
            }
            .sheet(isPresented: $showMealBudgetEditor) {
                MealBudgetEditorView(dataStore: dataStore)
            }
            .sheet(isPresented: $showEditProfileSheet) {
                EditProfileSheet(dataStore: dataStore)
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeySetupSheet(dataStore: dataStore)
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func exportDataJSON() {
        let exportData: [String: Any] = [
            "version": 1,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "loggedEntriesCount": dataStore.loggedEntries.count,
            "weightEntriesCount": dataStore.weightEntries.count
        ]
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let target = docs.appendingPathComponent("TrackYoCalories_Backup.json")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) {
            try? jsonData.write(to: target)
            self.exportURL = target
            self.showExportSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct EditProfileSheet: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var age: Int = 28
    @State private var gender: Gender = .male
    @State private var heightDisplay: Double = 178
    @State private var weightDisplay: Double = 75
    @State private var targetWeightDisplay: Double = 72
    @State private var goal: Goal = .fatLoss
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    
    var unitSystem: UnitSystem {
        dataStore.userProfile.unitSystem
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    Stepper("Age: \(age)", value: $age, in: 14...100)
                    Picker("Biological Sex", selection: $gender) {
                        ForEach(Gender.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }
                
                Section("Body Metrics (\(unitSystem.rawValue))") {
                    HStack {
                        Text("Height (\(unitSystem.heightUnit))")
                        Spacer()
                        TextField("Height", value: $heightDisplay, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Current Weight (\(unitSystem.weightUnit))")
                        Spacer()
                        TextField("Weight", value: $weightDisplay, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Target Weight (\(unitSystem.weightUnit))")
                        Spacer()
                        TextField("Target Weight", value: $targetWeightDisplay, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Activity & Goal") {
                    Picker("Primary Goal", selection: $goal) {
                        ForEach(Goal.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                }
            }
            .onAppear {
                let p = dataStore.userProfile
                name = p.name
                age = p.age
                gender = p.gender
                heightDisplay = unitSystem.cmToDisplay(p.heightCm)
                weightDisplay = unitSystem.kgToDisplay(p.weightKg)
                targetWeightDisplay = unitSystem.kgToDisplay(p.targetWeightKg)
                goal = p.goal
                activityLevel = p.activityLevel
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }
    
    private func save() {
        dataStore.userProfile.name = name
        dataStore.userProfile.age = age
        dataStore.userProfile.gender = gender
        dataStore.userProfile.heightCm = unitSystem.displayToCm(heightDisplay)
        dataStore.userProfile.weightKg = unitSystem.displayToKg(weightDisplay)
        dataStore.userProfile.targetWeightKg = unitSystem.displayToKg(targetWeightDisplay)
        dataStore.userProfile.goal = goal
        dataStore.userProfile.activityLevel = activityLevel
        dismiss()
    }
}
