//
//  FoodSearchView.swift
//  track yo calories
//

import SwiftUI

struct FoodSearchView: View {
    @ObservedObject var dataStore: DataStore
    var preselectedMeal: MealType = .breakfast
    var targetDate: Date = Date()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var searchTab: SearchTab = .all
    @State private var onlineResults: [FoodItem] = []
    @State private var isSearchingOnline: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    @State private var selectedFoodForDetail: FoodItem? = nil
    @State private var showAITextLog: Bool = false
    @State private var showScanner: Bool = false
    @State private var showAIScanner: Bool = false
    @State private var showQuickAdd: Bool = false
    @State private var showCreateFood: Bool = false
    
    enum SearchTab: String, CaseIterable, Identifiable {
        case all = "All"
        case database = "Staples"
        case recents = "Recents"
        case favorites = "Favorites"
        case custom = "My Foods"
        
        var id: String { rawValue }
    }
    
    var displayedItems: [FoodItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch searchTab {
        case .all:
            if q.isEmpty {
                return dataStore.recentFoods.isEmpty ? LocalFoodDatabaseService.shared.defaultStaples() : dataStore.recentFoods
            } else {
                let dbResults = LocalFoodDatabaseService.shared.search(query: q)
                let customMatches = (dataStore.customFoods + dataStore.favoriteFoods).filter { item in
                    item.name.localizedCaseInsensitiveContains(q) || (item.brand?.localizedCaseInsensitiveContains(q) ?? false)
                }
                var combined = customMatches
                for r in dbResults {
                    if !combined.contains(where: { $0.id == r.id }) {
                        combined.append(r)
                    }
                }
                for online in onlineResults {
                    if !combined.contains(where: { $0.id == online.id || ($0.barcode != nil && $0.barcode == online.barcode) || $0.name.lowercased() == online.name.lowercased() }) {
                        combined.append(online)
                    }
                }
                return combined
            }
            
        case .database:
            if q.isEmpty {
                return LocalFoodDatabaseService.shared.defaultStaples()
            } else {
                return LocalFoodDatabaseService.shared.search(query: q)
            }
            
        case .recents:
            if q.isEmpty {
                return dataStore.recentFoods
            } else {
                return dataStore.recentFoods.filter {
                    $0.name.lowercased().contains(q) || ($0.brand?.lowercased().contains(q) ?? false)
                }
            }
            
        case .favorites:
            if q.isEmpty {
                return dataStore.favoriteFoods
            } else {
                return dataStore.favoriteFoods.filter {
                    $0.name.lowercased().contains(q) || ($0.brand?.lowercased().contains(q) ?? false)
                }
            }
            
        case .custom:
            let list = dataStore.customFoods
            if q.isEmpty {
                return list
            } else {
                return list.filter {
                    $0.name.lowercased().contains(q) || ($0.brand?.lowercased().contains(q) ?? false)
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick Action Bar
                HStack(spacing: 8) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAITextLog = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                            Text("Describe")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.18))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { showAIScanner = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                            Text("Photo")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { showScanner = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 13, weight: .bold))
                            Text("Barcode")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { showQuickAdd = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.forwardslash.minus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Quick")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { showCreateFood = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Custom")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Segment Tabs
                Picker("Filter", selection: $searchTab) {
                    ForEach(SearchTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Food Results List
                List {
                    // AI Describe Quick Action Banner
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAITextLog = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(searchText.isEmpty ? "Describe What You Ate to AI" : "Estimate \"\(searchText)\" with AI")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(searchText.isEmpty ? "Type sentences like '2 eggs, toast, and a latte'" : "Instant calories & macros calculation")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
                    
                    if isSearchingOnline {
                        HStack {
                            Spacer()
                            ProgressView("Searching Open Food Facts...")
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    if displayedItems.isEmpty && !isSearchingOnline {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No items found")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Tap 'Describe What You Ate to AI' above to calculate calories automatically!")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(displayedItems) { item in
                            Button(action: {
                                selectedFoodForDetail = item
                            }) {
                                FoodSearchRow(food: item, isFavorite: dataStore.isFavorite(item))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search foods, or type what you ate...")
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .navigationTitle("Log Food (\(preselectedMeal.displayName))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAITextLog) {
                AITextFoodLogSheet(
                    dataStore: dataStore,
                    preselectedMeal: preselectedMeal,
                    targetDate: targetDate,
                    initialText: searchText,
                    onLogged: {
                        dismiss()
                    }
                )
            }
            .sheet(item: $selectedFoodForDetail) { food in
                FoodDetailView(
                    food: food,
                    dataStore: dataStore,
                    targetMeal: preselectedMeal,
                    targetDate: targetDate,
                    onLogged: {
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView(
                    dataStore: dataStore,
                    targetMeal: preselectedMeal,
                    targetDate: targetDate
                )
            }
            .sheet(isPresented: $showAIScanner) {
                AIFoodScannerView(
                    dataStore: dataStore,
                    targetMeal: preselectedMeal,
                    targetDate: targetDate
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
        }
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
            // Debounce for 350ms
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

struct FoodSearchRow: View {
    let food: FoodItem
    let isFavorite: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                    }
                }
                
                HStack(spacing: 6) {
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("• \(food.category)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(food.nutrientsPer100g.calories)) kcal")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("P:\(Int(food.nutrientsPer100g.protein))g C:\(Int(food.nutrientsPer100g.carbs))g F:\(Int(food.nutrientsPer100g.fat))g")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
