//
//  DateHeaderView.swift
//  track yo calories
//

import SwiftUI

/// Week of days under the navigation title. Tap a day to select it, swipe to change week.
struct WeekStripView: View {
    @Binding var selectedDate: Date
    let loggedDays: Set<Date>

    private var calendar: Calendar { Calendar.current }

    private var weekDays: [Date] {
        var startOfWeek = selectedDate
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &startOfWeek, interval: &interval, for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                dayButton(day)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    shiftWeek(value.translation.width < 0 ? 1 : -1)
                }
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: shiftDay(1)
            case .decrement: shiftDay(-1)
            @unknown default: break
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasEntries = loggedDays.contains(calendar.startOfDay(for: day))
        let weekdayIndex = calendar.component(.weekday, from: day) - 1

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedDate = day }
        } label: {
            VStack(spacing: 6) {
                Text(calendar.veryShortWeekdaySymbols[weekdayIndex])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color(.systemBackground) : (isToday ? Color.accentColor : Color.primary))
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            Circle().fill(isToday ? Color.accentColor : Color.primary)
                        }
                    }

                Circle()
                    .fill(hasEntries ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasEntries ? "Has logged food" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shiftWeek(_ weeks: Int) {
        guard let d = calendar.date(byAdding: .day, value: 7 * weeks, to: selectedDate) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { selectedDate = d }
    }

    private func shiftDay(_ days: Int) {
        guard let d = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = d
    }
}

struct CalendarPickerSheet: View {
    @Binding var selectedDate: Date
    let loggedDays: Set<Date>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .navigationTitle("Go to Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Today") {
                            selectedDate = Date()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .onChange(of: selectedDate) { _, _ in
                    dismiss()
                }
        }
        .presentationDetents([.medium, .large])
    }
}
