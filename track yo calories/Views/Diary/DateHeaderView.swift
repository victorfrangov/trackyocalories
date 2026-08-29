//
//  DateHeaderView.swift
//  track yo calories
//

import SwiftUI

struct DateHeaderView: View {
    @Binding var selectedDate: Date
    @ObservedObject var dataStore: DataStore
    var onOpenProfile: (() -> Void)? = nil
    
    @State private var showCalendarPicker: Bool = false
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    private var titleText: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return "Today"
        } else if cal.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else if cal.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            return selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }
    
    // 7 days of the current week (Monday to Sunday)
    private var weekDays: [Date] {
        let cal = Calendar.current
        var startOfWeek = selectedDate
        var interval: TimeInterval = 0
        _ = cal.dateInterval(of: .weekOfYear, start: &startOfWeek, interval: &interval, for: selectedDate)
        
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Top Bar: "Today ⌄" + Streak 🔥 + Avatar
            HStack {
                Button(action: { showCalendarPicker = true }) {
                    HStack(spacing: 6) {
                        Text(titleText)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Streak Counter
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    Text("\(calculateStreak())")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                
                // Profile Avatar Icon
                if let onOpenProfile = onOpenProfile {
                    Button(action: onOpenProfile) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            
            // Week Calendar Strip: M T W T F S S with active dots
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let hasEntries = !dataStore.entries(for: date).isEmpty
                    let dayLetter = weekdayLetter(for: date)
                    let dayNumber = Calendar.current.component(.day, from: date)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(dayLetter)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 32, height: 32)
                                    
                                    Text("\(dayNumber)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(.systemBackground))
                                } else {
                                    Text("\(dayNumber)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Calendar.current.isDateInToday(date) ? .orange : .primary)
                                        .frame(width: 32, height: 32)
                                }
                            }
                            
                            Circle()
                                .fill(hasEntries ? Color.orange : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .sheet(isPresented: $showCalendarPicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    
                    if !isToday {
                        Button("Jump to Today") {
                            selectedDate = Date()
                            showCalendarPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                }
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showCalendarPicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func weekdayLetter(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        // Sunday=1, Monday=2, Tuesday=3, Wednesday=4, Thursday=5, Friday=6, Saturday=7
        switch weekday {
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        case 1: return "S"
        default: return ""
        }
    }
    
    private func calculateStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        while true {
            if !dataStore.entries(for: checkDate).isEmpty {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                if cal.isDateInToday(checkDate) {
                    guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prev
                    continue
                }
                break
            }
        }
        return max(1, streak)
    }
}
