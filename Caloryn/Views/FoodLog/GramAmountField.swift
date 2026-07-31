import SwiftUI

/// A typed weight in grams, with a row of shortcut amounts beneath it.
///
/// This replaced a wheel of 5g steps. Reaching 340g from 100g there was
/// forty-eight rows of spinning, which users reported as the single most
/// annoying thing about logging — while a slice count, which never goes past
/// ten, is exactly what a wheel is good at. So grams are typed and counts are
/// still spun.
///
/// The field commits on submit and on losing focus rather than on every
/// keystroke: mid-edit the box can be empty or hold "3" on the way to "340",
/// and neither should be logged.
///
/// There is deliberately no "Done" toolbar above the keypad — it rendered as a
/// capsule floating over the nutrition rows, detached from anything. The keypad
/// is dismissed by scrolling instead, and the value is committed on save
/// regardless, so it never has to be dismissed at all.
struct GramAmountField: View {
    @Binding var text: String
    let quickOptions: [Int]
    let identifierPrefix: String
    let onTextChange: () -> Void
    let onCommit: () -> Void
    let onQuickOption: (Int) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // A `TextField` cannot roll its digits — `contentTransition`
                // has no effect on one. So the number is a `Text` whenever the
                // field is not being typed into, and tapping a shortcut rolls
                // it the way the calorie readout above rolls. The real field is
                // still in the hierarchy, merely invisible: focus cannot be
                // moved to a view that does not exist, so it cannot be swapped
                // in only once tapped.
                ZStack(alignment: .trailing) {
                    TextField("0", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit(onCommit)
                        .opacity(isFocused ? 1 : 0)
                        .accessibilityIdentifier("\(identifierPrefix).gramsField")
                        .accessibilityLabel("Portion in grams")

                    Text(text.isEmpty ? "0" : text)
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.3), value: text)
                        .opacity(isFocused ? 0 : 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.textPrimary)
                .fixedSize()

                Text("g")
                    .font(CalorynTheme.sectionTitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            // The same chrome as every other field in the app — the material
            // fill, the focus ring and its timing all come from there rather
            // than being restated. Only the padding is this field's own: the
            // shared one is sized for body text, and the number here is display
            // sized.
            .padding(.vertical, 6)
            .calorynInputField(isFocused: isFocused)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            HStack(spacing: 8) {
                ForEach(quickOptions, id: \.self) { grams in
                    quickOption(grams)
                }
            }
        }
        .onChange(of: text) { onTextChange() }
        .onChange(of: isFocused) { _, focused in
            if !focused { onCommit() }
        }
    }

    private func quickOption(_ grams: Int) -> some View {
        Button {
            // Focus goes first: the rolling number is the unfocused `Text`, so
            // changing the value before yielding focus would land it on the
            // field and skip the animation.
            isFocused = false
            onQuickOption(grams)
        } label: {
            // Sage marks the chosen chip and nothing else here — the calorie
            // readout is what should catch the eye on this screen, and three
            // green capsules under a green number competed with it.
            Text("\(grams)")
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(isSelected(grams) ? CalorynTheme.warmWhite : CalorynTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected(grams)
                                ? AnyShapeStyle(CalorynTheme.sage)
                                : AnyShapeStyle(.thinMaterial)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifierPrefix).quickGrams.\(grams)")
        .accessibilityLabel("\(grams) grams")
    }

    private func isSelected(_ grams: Int) -> Bool {
        text == "\(grams)"
    }
}
