//
//  FoodSearchView.swift
//  track yo calories
//

import SwiftUI
import PhotosUI

enum FitiaLogMode: String, CaseIterable, Identifiable {
    case recipes = "Recipes"
    case list = "List"
    case search = "Search"
    case scan = "Scan"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .recipes: return "book.closed"
        case .list: return "list.bullet"
        case .search: return "magnifyingglass"
        case .scan: return "camera"
        }
    }
}

struct FoodSearchView: View {
    @ObservedObject var dataStore: DataStore
    var preselectedMeal: MealType = .breakfast
    var targetDate: Date = Date()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var activeMode: FitiaLogMode = .search
    @State private var searchText: String = ""
    @State private var searchTab: FitiaSearchTab = .database
    @State private var onlineResults: [FoodItem] = []
    @State private var isSearchingOnline: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showAllRecents: Bool = false
    
    @State private var selectedFoodForDetail: FoodItem? = nil
    @State private var showQuickAdd: Bool = false
    @State private var showCreateFood: Bool = false
    @State private var showApiKeySheet: Bool = false
    
    // List Mode State
    @State private var activeMealInList: MealType = .breakfast
    @State private var listInputs: [MealType: [String]] = [
        .breakfast: [""],
        .lunch: [""],
        .dinner: [""],
        .snacks: [""]
    ]
    @State private var isEstimatingList: Bool = false
    @State private var estimatedAIResult: AIFoodEstimate? = nil
    @State private var listErrorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    
    // Scan Mode State
    @State private var scanMode: ScanSubMode = .photo
    
    enum ScanSubMode {
        case photo
        case barcode
    }
    
    enum FitiaSearchTab: String, CaseIterable, Identifiable {
        case database = "Database"
        case favorites = "Favorites"
        case created = "Created"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .database: return "archivebox"
            case .favorites: return "heart.fill"
            case .created: return "pencil"
            }
        }
    }
    
    init(dataStore: DataStore, preselectedMeal: MealType = .breakfast, targetDate: Date = Date()) {
        self.dataStore = dataStore
        self.preselectedMeal = preselectedMeal
        self.targetDate = targetDate
        self._activeMealInList = State(initialValue: preselectedMeal)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                // Active Mode View
                VStack(spacing: 0) {
                    switch activeMode {
                    case .search:
                        searchModeView
                    case .list:
                        listModeView
                    case .scan:
                        scanModeView
                    case .recipes:
                        recipesModeView
                    }
                }
                
                // Bottom Fitia Liquid Glass Floating Mode Bar
                bottomFloatingModeBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedFoodForDetail) { food in
                FoodDetailView(
                    food: food,
                    dataStore: dataStore,
                    targetMeal: preselectedMeal,
                    targetDate: targetDate,
                    onLogged: { dismiss() }
                )
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView(
                    dataStore: dataStore,
                    preselectedMeal: preselectedMeal,
                    targetDate: targetDate
                )
            }
            .sheet(isPresented: $showCreateFood) {
                CreateFoodView(dataStore: dataStore)
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeySetupSheet(dataStore: dataStore)
            }
            .sheet(item: $estimatedAIResult) { estimate in
                AIEstimateResultSheet(
                    dataStore: dataStore,
                    estimate: estimate,
                    preselectedMeal: activeMealInList,
                    targetDate: targetDate,
                    onLogged: { dismiss() }
                )
            }
            .alert("Could Not Estimate Meal", isPresented: $showErrorAlert) {
                if listErrorMessage?.contains("API key") == true {
                    Button("Set API Key") { showApiKeySheet = true }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(listErrorMessage ?? "An error occurred while estimating your meal.")
            }
        }
    }
    
    // MARK: - Search Mode View
    private var searchModeView: some View {
        VStack(spacing: 0) {
            // Search Bar & Options Menu (Swiss Flag removed)
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                    
                    TextField("Search foods", text: $searchText)
                        .font(.system(size: 15))
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                
                // More Options Menu (Quick Add, Custom Food)
                Menu {
                    Button(action: { showQuickAdd = true }) {
                        Label("Quick Add", systemImage: "plus.forwardslash.minus")
                    }
                    Button(action: { showCreateFood = true }) {
                        Label("Create Food / Recipe", systemImage: "plus.circle")
                    }
                    Button(action: { showApiKeySheet = true }) {
                        Label("AI Settings", systemImage: "key.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 38, height: 38)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            
            // Fitia Underline Tabs (Database | Favorites | Created)
            HStack(spacing: 0) {
                ForEach(FitiaSearchTab.allCases) { tab in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 13))
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: searchTab == tab ? .bold : .medium))
                            }
                            .foregroundColor(searchTab == tab ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(searchTab == tab ? Color.orange : Color.clear)
                                .frame(height: 2.5)
                                .cornerRadius(1.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            Divider()
                .padding(.top, 2)
            
            // Scroll Content based on active Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Searching active
                        searchResultsSection
                    } else {
                        // Switching tabs when searchText is empty
                        switch searchTab {
                        case .database:
                            databaseTabContent
                        case .favorites:
                            favoritesTabContent
                        case .created:
                            createdTabContent
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 100) // Padding for bottom floating bar
            }
        }
    }
    
    // MARK: - Tab Contents
    private var databaseTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            recentlyEnteredSection
            recentMealsSection
        }
    }
    
    private var favoritesTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FAVORITES")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            if dataStore.favoriteFoods.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Favorites Yet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Tap the star icon on any food item to add it to your favorites for quick logging.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(dataStore.favoriteFoods) { item in
                        Button(action: { selectedFoodForDetail = item }) {
                            fitiaFoodRow(item: item)
                        }
                        .buttonStyle(.plain)
                        
                        Divider().padding(.leading, 56)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var createdTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CUSTOM FOODS & RECIPES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showCreateFood = true }) {
                    Label("Create", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            
            let customList = dataStore.customFoods + dataStore.recipes.map { $0.toFoodItem() }
            
            if customList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Created Foods Yet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create your own custom food items with nutritional labels or recipes.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button(action: { showCreateFood = true }) {
                        Text("+ Create Food or Recipe")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(customList) { item in
                        Button(action: { selectedFoodForDetail = item }) {
                            fitiaFoodRow(item: item)
                        }
                        .buttonStyle(.plain)
                        
                        Divider().padding(.leading, 56)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSearchingOnline {
                HStack {
                    Spacer()
                    ProgressView("Searching foods...")
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            let results = getFilteredSearchResults()
            
            if results.isEmpty && !isSearchingOnline {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No foods found in \(searchTab.rawValue)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(results) { item in
                        Button(action: {
                            selectedFoodForDetail = item
                        }) {
                            fitiaFoodRow(item: item)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 56)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func getFilteredSearchResults() -> [FoodItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        
        switch searchTab {
        case .database:
            let dbResults = LocalFoodDatabaseService.shared.search(query: q)
            var combined = dbResults
            for online in onlineResults {
                if !combined.contains(where: { $0.id == online.id || ($0.barcode != nil && $0.barcode == online.barcode) || $0.name.lowercased() == online.name.lowercased() }) {
                    combined.append(online)
                }
            }
            return combined
            
        case .favorites:
            return dataStore.favoriteFoods.filter {
                $0.name.localizedCaseInsensitiveContains(q) || ($0.brand?.localizedCaseInsensitiveContains(q) ?? false)
            }
            
        case .created:
            let customList = dataStore.customFoods + dataStore.recipes.map { $0.toFoodItem() }
            return customList.filter {
                $0.name.localizedCaseInsensitiveContains(q) || ($0.brand?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }
    }
    
    // MARK: - Recently Entered Section
    private var recentlyEnteredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENTLY ENTERED")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            let recents = dataStore.recentFoods.isEmpty ? LocalFoodDatabaseService.shared.defaultStaples(limit: 6) : dataStore.recentFoods
            let itemsToShow = showAllRecents ? recents : Array(recents.prefix(5))
            
            VStack(spacing: 0) {
                ForEach(itemsToShow) { item in
                    Button(action: {
                        selectedFoodForDetail = item
                    }) {
                        fitiaFoodRow(item: item)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 56)
                }
                
                if recents.count > 5 {
                    Button(action: {
                        withAnimation {
                            showAllRecents.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(showAllRecents ? "SHOW LESS" : "SHOW MORE")
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: showAllRecents ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Recent Meals Section
    private var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT MEALS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            let recentMealGroups = buildRecentMealGroups()
            
            if recentMealGroups.isEmpty {
                VStack(spacing: 6) {
                    Text("No past meals logged yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentMealGroups, id: \.id) { group in
                        Button(action: {
                            logRecentMealGroup(group)
                        }) {
                            HStack(spacing: 12) {
                                Text(group.emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(group.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(group.foodCount) food\(group.foodCount == 1 ? "" : "s")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text("\(Int(group.totalCalories)) kcal")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 56)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Fitia Food Row Component
    private func fitiaFoodRow(item: FoodItem) -> some View {
        HStack(spacing: 12) {
            Text(emojiForFood(item))
                .font(.system(size: 22))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if item.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(item.brand?.isEmpty == false ? item.brand! : item.category)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                let defaultOption = item.effectiveServingOptions.first(where: { $0.isDefault }) ?? item.effectiveServingOptions.first
                Text(defaultOption?.name ?? "100g")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("\(Int(item.nutrientsPer100g.calories)) kcal")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - List Mode View (Screenshot 1)
    private var listModeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("List")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                ForEach(MealType.allCases) { meal in
                    mealListCard(meal: meal)
                }
                
                // Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    submitListToAI()
                }) {
                    HStack(spacing: 8) {
                        if isEstimatingList {
                            ProgressView()
                                .tint(.white)
                            Text("Estimating with AI...")
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                            Text("Estimate & Log with AI")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isEstimatingList ? Color.orange.opacity(0.6) : Color.orange)
                    .cornerRadius(18)
                    .shadow(color: Color.orange.opacity(0.35), radius: 8, y: 4)
                }
                .disabled(isEstimatingList)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
    }
    
    private func mealListCard(meal: MealType) -> some View {
        let isSelected = activeMealInList == meal
        let items = listInputs[meal] ?? [""]
        
        return VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                activeMealInList = meal
            }) {
                Text(meal.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? .orange : .primary)
            }
            
            ForEach(0..<items.count, id: \.self) { idx in
                HStack(spacing: 8) {
                    Circle()
                        .fill(isSelected ? Color.orange : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    
                    TextField("Type a food (e.g. Croissant 1 medium)", text: Binding(
                        get: { listInputs[meal]?[idx] ?? "" },
                        set: { listInputs[meal]?[idx] = $0 }
                    ))
                    .font(.system(size: 15))
                    
                    if idx == items.count - 1 {
                        Button(action: {
                            listInputs[meal]?.append("")
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.orange.opacity(0.8) : Color.clear, lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .onTapGesture {
            activeMealInList = meal
        }
    }
    
    private func submitListToAI() {
        let items = (listInputs[activeMealInList] ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let prompt = items.joined(separator: ", ")
        guard !prompt.isEmpty else { return }
        
        guard let key = dataStore.userProfile.geminiApiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showApiKeySheet = true
            return
        }
        
        isEstimatingList = true
        estimatedAIResult = nil
        listErrorMessage = nil
        
        Task {
            do {
                let estimate = try await AIFoodScannerService.shared.analyzeFoodDescription(text: prompt, apiKey: key)
                await MainActor.run {
                    self.estimatedAIResult = estimate
                    self.isEstimatingList = false
                }
            } catch {
                await MainActor.run {
                    self.isEstimatingList = false
                    self.listErrorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Scan Mode View
    private var scanModeView: some View {
        ZStack {
            if scanMode == .photo {
                CustomAICameraView { capturedImage in
                    dismiss()
                }
            } else {
                BarcodeScannerView(
                    dataStore: dataStore,
                    targetMeal: preselectedMeal,
                    targetDate: targetDate
                )
            }
            
            // Sub-mode pill: [ Photo ] [ Barcode ]
            VStack {
                Spacer()
                
                HStack(spacing: 0) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        scanMode = .photo
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                            Text("Photo")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(scanMode == .photo ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(scanMode == .photo ? Color.orange : Color.clear)
                        .cornerRadius(20)
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        scanMode = .barcode
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "barcode.viewfinder")
                            Text("Barcode")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(scanMode == .barcode ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(scanMode == .barcode ? Color.orange : Color.clear)
                        .cornerRadius(20)
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 110)
            }
        }
    }
    
    // MARK: - Recipes Mode View
    private var recipesModeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recipes")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: { showCreateFood = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                if dataStore.recipes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No custom recipes yet")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Combine multiple ingredients into custom meals")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)
                } else {
                    ForEach(dataStore.recipes) { recipe in
                        fitiaFoodRow(item: recipe.toFoodItem())
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Fitia Liquid Glass Floating Mode Bar (4 Modes: Recipes, List, Search, Scan)
    private var bottomFloatingModeBar: some View {
        HStack(spacing: 8) {
            ForEach(FitiaLogMode.allCases) { mode in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        activeMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: activeMode == mode ? 16 : 17, weight: activeMode == mode ? .bold : .medium))
                        
                        if activeMode == mode {
                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(activeMode == mode ? .white : .secondary)
                    .padding(.horizontal, activeMode == mode ? 16 : 14)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if activeMode == mode {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange, Color.orange.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.orange.opacity(0.4), radius: 8, y: 3)
                            }
                        }
                    )
                }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helpers
    private func emojiForFood(_ item: FoodItem) -> String {
        let name = item.name.lowercased()
        let cat = item.category.lowercased()
        
        if name.contains("croissant") || name.contains("bread") || name.contains("toast") || cat.contains("bakery") {
            return "🥐"
        } else if name.contains("egg") {
            return "🥚"
        } else if name.contains("corn") {
            return "🌽"
        } else if name.contains("banana") {
            return "🍌"
        } else if name.contains("apple") {
            return "🍎"
        } else if name.contains("beef") || name.contains("steak") || name.contains("meat") {
            return "🥩"
        } else if name.contains("chicken") || name.contains("poultry") {
            return "🍗"
        } else if name.contains("lasagna") || name.contains("pasta") {
            return "✨"
        } else if name.contains("coffee") || name.contains("latte") || name.contains("cappuccino") {
            return "☕️"
        } else if name.contains("milk") || name.contains("yogurt") || name.contains("cheese") {
            return "🥛"
        } else if name.contains("rice") || name.contains("bowl") {
            return "🍚"
        } else if name.contains("salad") || name.contains("vegetable") {
            return "🥗"
        }
        return "🍽️"
    }
    
    private struct RecentMealGroup: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let foodCount: Int
        let totalCalories: Double
        let emoji: String
        let entries: [LoggedEntry]
    }
    
    private func buildRecentMealGroups() -> [RecentMealGroup] {
        let entries = dataStore.loggedEntries
        guard !entries.isEmpty else {
            return [
                RecentMealGroup(
                    title: "Breakfast (Yesterday)",
                    subtitle: "Croissant, Black Coffee",
                    foodCount: 2,
                    totalCalories: 231,
                    emoji: "🥐",
                    entries: []
                ),
                RecentMealGroup(
                    title: "Breakfast (Friday)",
                    subtitle: "Croissant, Butter",
                    foodCount: 1,
                    totalCalories: 231,
                    emoji: "🥐",
                    entries: []
                ),
                RecentMealGroup(
                    title: "Breakfast (Thursday)",
                    subtitle: "2 Scrambled Eggs",
                    foodCount: 1,
                    totalCalories: 286,
                    emoji: "🥚",
                    entries: []
                )
            ]
        }
        
        let calendar = Calendar.current
        let groupedByDateMeal = Dictionary(grouping: entries) { entry -> String in
            let dateStr = calendar.isDateInYesterday(entry.date) ? "Yesterday" : calendar.isDateInToday(entry.date) ? "Today" : entry.date.formatted(.dateTime.weekday())
            return "\(entry.mealType.displayName) (\(dateStr))"
        }
        
        return groupedByDateMeal.prefix(4).map { key, items in
            let totalCals = items.reduce(0.0) { $0 + $1.calories }
            let foodNames = items.map { $0.food.name }.joined(separator: ", ")
            let firstEmoji = items.first.map { emojiForFood($0.food) } ?? "🍽️"
            return RecentMealGroup(
                title: key,
                subtitle: foodNames,
                foodCount: items.count,
                totalCalories: totalCals,
                emoji: firstEmoji,
                entries: items
            )
        }
    }
    
    private func logRecentMealGroup(_ group: RecentMealGroup) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for entry in group.entries {
            dataStore.logFood(
                food: entry.food,
                mealType: preselectedMeal,
                serving: entry.servingOption,
                quantity: entry.quantity,
                date: targetDate
            )
        }
        dismiss()
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            onlineResults = []
            isSearchingOnline = false
            return
        }
        
        isSearchingOnline = true
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await OpenFoodFactsService.shared.searchProducts(query: trimmed)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.onlineResults = results
                    self.isSearchingOnline = false
                }
            } catch {
                await MainActor.run {
                    self.isSearchingOnline = false
                }
            }
        }
    }
}
