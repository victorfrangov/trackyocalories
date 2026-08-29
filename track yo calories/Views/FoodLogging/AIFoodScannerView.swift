//
//  AIFoodScannerView.swift
//  track yo calories
//

import SwiftUI
import PhotosUI

struct AIFoodScannerView: View {
    @ObservedObject var dataStore: DataStore
    var targetMeal: MealType
    var targetDate: Date
    var onLogged: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCameraPicker: Bool = false
    
    @State private var isAnalyzing: Bool = false
    @State private var aiEstimate: AIFoodEstimate? = nil
    @State private var errorMessage: String? = nil
    
    // Fine-Tuning State
    @State private var editedFoodName: String = ""
    @State private var portionAmount: Double = 100.0
    @State private var portionUnit: String = "g" // "g" or "mL"
    @State private var editedCalories: Double = 0.0
    @State private var editedProtein: Double = 0.0
    @State private var editedCarbs: Double = 0.0
    @State private var editedFat: Double = 0.0
    
    // Baseline per-gram density from initial AI scan for dynamic portion scaling
    @State private var baseCalPerGram: Double = 1.0
    @State private var baseProteinPerGram: Double = 0.1
    @State private var baseCarbsPerGram: Double = 0.1
    @State private var baseFatPerGram: Double = 0.05
    
    @State private var selectedMeal: MealType
    @State private var showApiKeySheet: Bool = false
    
    init(dataStore: DataStore, targetMeal: MealType = .breakfast, targetDate: Date = Date(), onLogged: (() -> Void)? = nil) {
        self.dataStore = dataStore
        self.targetMeal = targetMeal
        self.targetDate = targetDate
        self.onLogged = onLogged
        self._selectedMeal = State(initialValue: targetMeal)
    }
    
    var apiKey: String? {
        dataStore.userProfile.geminiApiKey
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let image = selectedImage {
                        imagePreviewSection(image: image)
                    } else {
                        photoSelectionSection
                    }
                    
                    if isAnalyzing {
                        analyzingLoadingSection
                    } else if aiEstimate != nil {
                        fineTuningSection
                    }
                    
                    if let error = errorMessage {
                        errorSection(error: error)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Food Photo Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showApiKeySheet = true }) {
                        Image(systemName: apiKey?.isEmpty == false ? "key.fill" : "key")
                            .foregroundColor(apiKey?.isEmpty == false ? .green : .orange)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CustomAICameraView { capturedImage in
                    selectedImage = capturedImage
                    analyzePhoto(image: capturedImage)
                }
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeySetupSheet(dataStore: dataStore) {
                    if let img = selectedImage {
                        analyzePhoto(image: img)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = img
                            analyzePhoto(image: img)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Photo Picker Screen
    @ViewBuilder
    private var photoSelectionSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                
                Text("Scan Your Meal with AI")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("Take or upload a picture of your food. Google Gemini AI estimates ingredients, calories, and macros.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            
            HStack(spacing: 16) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCameraPicker = true
                }) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                        Text("Take Photo")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(18)
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                        Text("Photo Library")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(18)
                }
            }
            .padding(.horizontal)
            
            if apiKey == nil || apiKey?.isEmpty == true {
                Button(action: { showApiKeySheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                        Text("Set up free Google AI Studio API Key")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Image Preview
    @ViewBuilder
    private func imagePreviewSection(image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()
                .cornerRadius(18)
            
            Button(action: {
                selectedImage = nil
                aiEstimate = nil
                errorMessage = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Loading Animation
    @ViewBuilder
    private var analyzingLoadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.3)
            Text("AI is identifying food items & calculating macros...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Interactive Fine-Tuning Studio
    @ViewBuilder
    private var fineTuningSection: some View {
        VStack(spacing: 16) {
            // Food Name & Confidence
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Food Title")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let conf = aiEstimate?.confidence {
                        Text("\(conf) Confidence")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                }
                
                TextField("Food Name", text: $editedFoodName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(10)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(18)
            .padding(.horizontal)
            
            // Portion Size & Unit (g vs mL)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Portion Size")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Picker("Unit", selection: $portionUnit) {
                        Text("Grams (g)").tag("g")
                        Text("Milliliters (mL)").tag("mL")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                
                HStack(spacing: 12) {
                    TextField("Amount", value: $portionAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(10)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .onChange(of: portionAmount) { _, newAmount in
                            recalculateFromPortion(newAmount: newAmount)
                        }
                    
                    Text(portionUnit)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                // Quick Adjust Steppers
                HStack(spacing: 8) {
                    PortionQuickButton(label: "-50", delta: -50, onApply: applyPortionDelta)
                    PortionQuickButton(label: "-10", delta: -10, onApply: applyPortionDelta)
                    PortionQuickButton(label: "+10", delta: 10, onApply: applyPortionDelta)
                    PortionQuickButton(label: "+50", delta: 50, onApply: applyPortionDelta)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(18)
            .padding(.horizontal)
            
            // Macro Fine-Tuning Grid
            VStack(spacing: 12) {
                HStack {
                    Text("Fine-Tune Nutrition")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("Editable")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Calories Card
                MacroFineTuneRow(
                    label: "Calories",
                    unit: "kcal",
                    value: $editedCalories,
                    step: 10,
                    color: .orange
                )
                
                Divider()
                
                // Protein Card
                MacroFineTuneRow(
                    label: "Protein",
                    unit: "g",
                    value: $editedProtein,
                    step: 1,
                    color: .orange
                )
                
                Divider()
                
                // Carbs Card
                MacroFineTuneRow(
                    label: "Carbohydrates",
                    unit: "g",
                    value: $editedCarbs,
                    step: 1,
                    color: .blue
                )
                
                Divider()
                
                // Fat Card
                MacroFineTuneRow(
                    label: "Total Fat",
                    unit: "g",
                    value: $editedFat,
                    step: 1,
                    color: .purple
                )
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(18)
            .padding(.horizontal)
            
            // Detected Ingredients List
            if let ingredients = aiEstimate?.ingredientsDetected, !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Ingredients")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    ForEach(ingredients, id: \.self) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text(item)
                                .font(.system(size: 13))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(18)
                .padding(.horizontal)
            }
            
            // Meal Selector
            HStack {
                Text("Log to Meal")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(MealType.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(18)
            .padding(.horizontal)
            
            // Log to Diary Button
            Button(action: logFineTunedFood) {
                Text("Log to Diary (\(Int(editedCalories)) kcal)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Error Display
    @ViewBuilder
    private func errorSection(error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Analysis Notice")
                    .font(.system(size: 15, weight: .bold))
            }
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            if apiKey == nil || apiKey?.isEmpty == true {
                Button("Enter Gemini API Key") {
                    showApiKeySheet = true
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }
    
    // MARK: - Logic
    private func analyzePhoto(image: UIImage) {
        guard let key = apiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showApiKeySheet = true
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        aiEstimate = nil
        
        Task {
            do {
                let estimate = try await AIFoodScannerService.shared.analyzeFood(image: image, apiKey: key)
                await MainActor.run {
                    self.aiEstimate = estimate
                    self.editedFoodName = estimate.foodName
                    let grams = max(10.0, estimate.estimatedGrams)
                    self.portionAmount = grams
                    self.editedCalories = estimate.calories
                    self.editedProtein = estimate.protein
                    self.editedCarbs = estimate.carbs
                    self.editedFat = estimate.fat
                    
                    // Set base densities
                    self.baseCalPerGram = estimate.calories / grams
                    self.baseProteinPerGram = estimate.protein / grams
                    self.baseCarbsPerGram = estimate.carbs / grams
                    self.baseFatPerGram = estimate.fat / grams
                    
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func applyPortionDelta(_ delta: Double) {
        let newAmount = max(5, portionAmount + delta)
        portionAmount = newAmount
        recalculateFromPortion(newAmount: newAmount)
    }
    
    private func recalculateFromPortion(newAmount: Double) {
        editedCalories = max(0, (newAmount * baseCalPerGram).rounded())
        editedProtein = max(0, (newAmount * baseProteinPerGram * 10).rounded() / 10)
        editedCarbs = max(0, (newAmount * baseCarbsPerGram * 10).rounded() / 10)
        editedFat = max(0, (newAmount * baseFatPerGram * 10).rounded() / 10)
    }
    
    private func logFineTunedFood() {
        let grams = max(1.0, portionAmount)
        let factor = 100.0 / grams
        
        let nutrients100g = NutrientInfo(
            calories: editedCalories * factor,
            protein: editedProtein * factor,
            carbs: editedCarbs * factor,
            fat: editedFat * factor,
            fiber: aiEstimate?.fiber.map { $0 * factor },
            sugar: aiEstimate?.sugar.map { $0 * factor },
            sodium: aiEstimate?.sodium.map { $0 * factor }
        )
        
        let serving = ServingOption(
            id: UUID(),
            name: "\(Int(portionAmount)) \(portionUnit)",
            gramWeight: grams,
            isDefault: true
        )
        
        let food = FoodItem(
            id: UUID(),
            barcode: nil,
            name: editedFoodName.isEmpty ? "AI Scanned Meal" : editedFoodName,
            brand: "AI Estimated",
            category: "AI Meal Scan",
            nutrientsPer100g: nutrients100g,
            servingOptions: [
                serving,
                ServingOption(id: UUID(), name: "1 \(portionUnit)", gramWeight: 1.0, isDefault: false),
                ServingOption.grams(100.0)
            ],
            isCustom: true,
            isVerified: true
        )
        
        dataStore.logFood(
            food: food,
            mealType: selectedMeal,
            serving: serving,
            quantity: 1.0,
            date: targetDate
        )
        
        onLogged?()
        dismiss()
    }
}

// MARK: - Macro Fine Tune Row Component
struct MacroFineTuneRow: View {
    let label: String
    let unit: String
    @Binding var value: Double
    let step: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { value = max(0, value - step) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                
                TextField("0", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 50)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                
                Text(unit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .leading)
                
                Button(action: { value += step }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
            }
        }
    }
}

// MARK: - Portion Quick Button
struct PortionQuickButton: View {
    let label: String
    let delta: Double
    let onApply: (Double) -> Void
    
    var body: some View {
        Button(action: { onApply(delta) }) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(10)
        }
    }
}

// MARK: - Camera Picker UIKit Representable
struct CameraPickerRepresentable: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Gemini API Key Setup Sheet
struct ApiKeySetupSheet: View {
    @ObservedObject var dataStore: DataStore
    var onKeySaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var keyText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google AI Studio Gemini Key")
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("Gemini 3.6 Flash is 100% free with 1,500 requests per day. No credit card required.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Link("Get a Free API Key (aistudio.google.com) ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Your API Key") {
                    SecureField("Paste AI Studio API Key here", text: $keyText)
                }
            }
            .onAppear {
                keyText = dataStore.userProfile.geminiApiKey ?? ""
            }
            .navigationTitle("AI Vision Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
                        dataStore.userProfile.geminiApiKey = trimmed.isEmpty ? nil : trimmed
                        dismiss()
                        if !trimmed.isEmpty {
                            onKeySaved?()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
