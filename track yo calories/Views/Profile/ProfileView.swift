//
//  ProfileView.swift
//  track yo calories
//

import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @ObservedObject var dataStore: DataStore

    @State private var showMacroEditor: Bool = false
    @State private var showMealBudgetEditor: Bool = false
    @State private var showEditProfileSheet: Bool = false
    @State private var showApiKeySheet: Bool = false
    @State private var exportURL: URL? = nil
    @State private var showImporter: Bool = false
    @State private var pendingImportURL: URL? = nil
    @State private var showRedoSetupConfirm: Bool = false
    @State private var alertMessage: String? = nil

    private var profile: UserProfile { dataStore.userProfile }
    private var unitSystem: UnitSystem { profile.unitSystem }
    private var macroTargets: MacroTargets { NutritionEngine.calculateMacroTargets(profile: profile) }

    private var hasApiKey: Bool { profile.geminiApiKey?.isEmpty == false }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showEditProfileSheet = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.title3.weight(.semibold))
                                Text("\(profile.goal.rawValue) · \(weightString(profile.weightKg)) → \(weightString(profile.targetWeightKg))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    navigationRow(
                        title: "Calories & Macros",
                        detail: "\(macroTargets.calories.roundedString) kcal · P \(macroTargets.proteinGrams.roundedString) · C \(macroTargets.carbsGrams.roundedString) · F \(macroTargets.fatGrams.roundedString)"
                    ) { showMacroEditor = true }

                    navigationRow(
                        title: "Meal Split",
                        detail: "Breakfast \(pct(profile.breakfastRatio)) · Lunch \(pct(profile.lunchRatio)) · Dinner \(pct(profile.dinnerRatio)) · Snacks \(pct(profile.snacksRatio))"
                    ) { showMealBudgetEditor = true }

                    Stepper(value: waterGoalBinding, in: 500...6000, step: unitSystem == .metric ? 250 : 236.588) {
                        HStack {
                            Text("Water Goal")
                            Spacer()
                            Text(waterString(profile.waterGoalMl))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Daily Targets")
                } footer: {
                    Text("Estimated burn: \(NutritionEngine.calculateTDEE(profile: profile).roundedString) kcal/day (BMR \(NutritionEngine.calculateBMR(profile: profile).roundedString) kcal).")
                }

                Section {
                    Picker("Units", selection: $dataStore.userProfile.unitSystem) {
                        Text("Metric").tag(UnitSystem.metric)
                        Text("Imperial").tag(UnitSystem.imperial)
                    }

                    Button {
                        showApiKeySheet = true
                    } label: {
                        HStack {
                            Text("AI Estimates (Gemini)")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(hasApiKey ? "On" : "Not Set Up")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Preferences")
                }

                Section {
                    Button {
                        do {
                            exportURL = try dataStore.exportBackup()
                        } catch {
                            alertMessage = "Couldn’t create the backup: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("Restore from Backup…", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showRedoSetupConfirm = true
                    } label: {
                        Label("Redo Setup", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Backups include your diary, weigh-ins, water, foods and recipes. Your API key is never included.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
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
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): pendingImportURL = url
                case .failure(let error): alertMessage = error.localizedDescription
                }
            }
            .confirmationDialog(
                "Replace all data with this backup?",
                isPresented: Binding(get: { pendingImportURL != nil }, set: { if !$0 { pendingImportURL = nil } }),
                titleVisibility: .visible
            ) {
                Button("Replace All Data", role: .destructive) {
                    guard let url = pendingImportURL else { return }
                    do {
                        try dataStore.importBackup(from: url)
                        alertMessage = "Backup restored."
                    } catch {
                        alertMessage = "This file isn’t a valid Track Yo Calories backup."
                    }
                    pendingImportURL = nil
                }
            } message: {
                Text("Everything currently in the app is replaced. Export a backup first if you want to keep it.")
            }
            .confirmationDialog("Redo setup?", isPresented: $showRedoSetupConfirm, titleVisibility: .visible) {
                Button("Redo Setup") {
                    dataStore.userProfile.isOnboarded = false
                }
            } message: {
                Text("You’ll go through the setup questions again to recalculate your targets. Your diary and history are kept.")
            }
            .alert("Backup", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var waterGoalBinding: Binding<Double> {
        Binding(
            get: { dataStore.userProfile.waterGoalMl },
            set: { dataStore.userProfile.waterGoalMl = $0.rounded() }
        )
    }

    private func navigationRow(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func pct(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private func weightString(_ kg: Double) -> String {
        "\(unitSystem.kgToDisplay(kg).formatted(.number.precision(.fractionLength(0...1)))) \(unitSystem.weightUnit)"
    }

    private func waterString(_ ml: Double) -> String {
        let value = unitSystem.mlToDisplay(ml)
        return unitSystem == .metric ? "\(value.roundedString) ml" : "\(value.roundedString) fl oz"
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
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
    @State private var weeklyChangeKg: Double = -0.5
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var loaded = false

    private var unitSystem: UnitSystem { dataStore.userProfile.unitSystem }

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    TextField("Name", text: $name)
                    Stepper("Age: \(age)", value: $age, in: 14...100)
                    Picker("Sex", selection: $gender) {
                        ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                    }
                    measurementRow("Height", unit: unitSystem.heightUnit, value: $heightDisplay)
                }

                Section {
                    measurementRow("Current Weight", unit: unitSystem.weightUnit, value: $weightDisplay)
                    measurementRow("Goal Weight", unit: unitSystem.weightUnit, value: $targetWeightDisplay)
                    Picker("Goal", selection: $goal) {
                        ForEach(Goal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: goal) { _, newGoal in
                        if loaded { weeklyChangeKg = newGoal.defaultWeeklyChangeKg }
                    }
                    if goal != .maintenance {
                        Picker("Weekly Pace", selection: $weeklyChangeKg) {
                            ForEach(WeeklyPace.options(for: goal), id: \.self) { kg in
                                Text(WeeklyPace.label(kg, unitSystem: unitSystem)).tag(kg)
                            }
                        }
                    }
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Changing your current weight here also records a weigh-in for today.")
                }

                Section("Activity") {
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            VStack(alignment: .leading) {
                                Text(level.rawValue)
                                Text(level.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .onAppear {
                guard !loaded else { return }
                let p = dataStore.userProfile
                name = p.name
                age = p.age
                gender = p.gender
                heightDisplay = unitSystem.cmToDisplay(p.heightCm)
                weightDisplay = unitSystem.kgToDisplay(p.weightKg)
                targetWeightDisplay = unitSystem.kgToDisplay(p.targetWeightKg)
                goal = p.goal
                weeklyChangeKg = WeeklyPace.options(for: p.goal).contains(p.weeklyChangeKg) ? p.weeklyChangeKg : p.goal.defaultWeeklyChangeKg
                activityLevel = p.activityLevel
                DispatchQueue.main.async { loaded = true }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(heightDisplay <= 0 || weightDisplay <= 0 || targetWeightDisplay <= 0)
                }
            }
        }
    }

    private func measurementRow(_ title: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DecimalField(title: title, value: value, fractionDigits: 1)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let newWeightKg = unitSystem.displayToKg(weightDisplay)
        let weightChanged = abs(newWeightKg - dataStore.userProfile.weightKg) >= 0.05

        var p = dataStore.userProfile
        p.name = trimmedName.isEmpty ? p.name : trimmedName
        p.age = age
        p.gender = gender
        p.heightCm = unitSystem.displayToCm(heightDisplay)
        p.targetWeightKg = unitSystem.displayToKg(targetWeightDisplay)
        p.goal = goal
        p.weeklyChangeKg = goal == .maintenance ? 0 : weeklyChangeKg
        p.activityLevel = activityLevel
        dataStore.userProfile = p

        if weightChanged {
            // Recording a weigh-in keeps the chart and the calorie targets consistent.
            dataStore.logWeight(weightKg: newWeightKg, date: Date())
        }
        dismiss()
    }
}

/// Selectable weekly weight-change rates for a goal.
enum WeeklyPace {
    static func options(for goal: Goal) -> [Double] {
        switch goal {
        case .fatLoss: return [-0.25, -0.5, -0.75, -1.0]
        case .muscleGain: return [0.1, 0.25, 0.5]
        case .maintenance: return [0]
        }
    }

    static func label(_ kg: Double, unitSystem: UnitSystem) -> String {
        let value = abs(unitSystem.kgToDisplay(kg))
        let verb = kg < 0 ? "Lose" : "Gain"
        return "\(verb) \(value.formatted(.number.precision(.fractionLength(0...2)))) \(unitSystem.weightUnit) / week"
    }
}
