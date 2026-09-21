//
//  AIFoodScannerView.swift
//  track yo calories
//

import SwiftUI
import PhotosUI

/// Photo → Gemini estimate → per-item review (AIEstimateResultSheet) → diary.
struct AIFoodScannerView: View {
    @ObservedObject var dataStore: DataStore
    var targetMeal: MealType = .breakfast
    var targetDate: Date = Date()
    var onLogged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var isAnalyzing: Bool = false
    @State private var estimate: AIFoodEstimate? = nil
    @State private var errorMessage: String? = nil
    @State private var showApiKeySheet: Bool = false
    @State private var analysisTask: Task<Void, Never>? = nil

    init(dataStore: DataStore, targetMeal: MealType = .breakfast, targetDate: Date = Date(), onLogged: (() -> Void)? = nil) {
        self.dataStore = dataStore
        self.targetMeal = targetMeal
        self.targetDate = targetDate
        self.onLogged = onLogged
    }

    private var apiKey: String? {
        let key = dataStore.userProfile.geminiApiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == false ? key : nil
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityLabel("Selected meal photo")

                        if isAnalyzing {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text("Estimating calories…")
                                    .font(.headline)
                                Text("This usually takes a few seconds.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("Cancel") { cancelAnalysis() }
                                    .buttonStyle(.bordered)
                            }
                            .padding(.top, 8)
                        } else if let errorMessage {
                            VStack(spacing: 12) {
                                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                HStack {
                                    Button("Try Again") { analyze(image) }
                                        .buttonStyle(.borderedProminent)
                                    Button("Choose Another Photo") { reset() }
                                        .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            Button("Choose Another Photo") { reset() }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        pickerContent
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Photo Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelAnalysis()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showApiKeySheet = true
                    } label: {
                        Label("AI Settings", systemImage: "key")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CustomAICameraView { captured in
                    selectedImage = captured
                    analyze(captured)
                }
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeySetupSheet(dataStore: dataStore) {
                    if let image = selectedImage { analyze(image) }
                }
            }
            .sheet(item: $estimate) { result in
                AIEstimateResultSheet(
                    dataStore: dataStore,
                    estimate: result,
                    preselectedMeal: targetMeal,
                    targetDate: targetDate,
                    onLogged: {
                        onLogged?()
                        dismiss()
                    }
                )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        analyze(image)
                    } else {
                        errorMessage = "That photo couldn’t be loaded. Try a different one."
                    }
                }
            }
        }
    }

    private var pickerContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "camera.macro")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("Estimate a Meal from a Photo")
                    .font(.title3.weight(.semibold))
                Text("Gemini identifies each food and estimates its portion, calories and macros. You can adjust everything before it’s added to \(targetMeal.displayName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!cameraAvailable)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if apiKey == nil {
                Button {
                    showApiKeySheet = true
                } label: {
                    Label("Set up a free Gemini API key first", systemImage: "key.fill")
                }
                .font(.subheadline)
            }
        }
    }

    private func reset() {
        cancelAnalysis()
        selectedImage = nil
        selectedPhotoItem = nil // lets the same photo be picked again
        errorMessage = nil
    }

    private func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
    }

    private func analyze(_ image: UIImage) {
        guard let key = apiKey else {
            showApiKeySheet = true
            return
        }
        analysisTask?.cancel()
        isAnalyzing = true
        errorMessage = nil
        analysisTask = Task {
            do {
                let result = try await AIFoodScannerService.shared.analyzeFood(image: image, apiKey: key)
                guard !Task.isCancelled else { return }
                estimate = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

// MARK: - Gemini API Key Setup Sheet
struct ApiKeySetupSheet: View {
    @ObservedObject var dataStore: DataStore
    var onKeySaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var keyText: String = ""

    private var hasSavedKey: Bool {
        dataStore.userProfile.geminiApiKey?.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste your API key", text: $keyText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Google Gemini API Key")
                } footer: {
                    Text("Used for photo and text calorie estimates. Google AI Studio offers a free tier; the key is stored only on this device and never included in backups.")
                }

                Section {
                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                        Label("Get a Free Key from Google AI Studio", systemImage: "arrow.up.right.square")
                    }
                    if hasSavedKey {
                        Button("Remove Saved Key", role: .destructive) {
                            dataStore.userProfile.geminiApiKey = nil
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                keyText = dataStore.userProfile.geminiApiKey ?? ""
            }
            .navigationTitle("AI Settings")
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
        .presentationDetents([.medium, .large])
    }
}
