//
//  DecimalField.swift
//  track yo calories
//

import SwiftUI

/// A number field bound to a Double that updates while typing and accepts "," or "." decimals.
/// (`TextField(value:format:)` only commits on Return/focus loss, so tapping Save could lose the last edit.)
struct DecimalField: View {
    let title: String
    @Binding var value: Double
    var fractionDigits: Int = 1
    var onFocusChange: ((Bool) -> Void)? = nil

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(fractionDigits == 0 ? .numberPad : .decimalPad)
            .monospacedDigit()
            .focused($focused)
            .onAppear { text = format(value) }
            .onChange(of: text) { _, newText in
                if let parsed = Double(userInput: newText), parsed != value {
                    value = parsed
                }
            }
            .onChange(of: value) { _, newValue in
                // Reflect outside changes (steppers, scaling) unless the user is typing.
                if !focused { text = format(newValue) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = format(value) }
                onFocusChange?(isFocused)
            }
    }

    private func format(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...fractionDigits)).grouping(.never))
    }
}
