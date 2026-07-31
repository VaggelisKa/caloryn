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
/// capsule floating over the nutrition rows, detached from anything. A number
/// pad has no return key either, so the ways out are tapping anywhere off the
/// field and scrolling, both of which the screen owning this field installs.
///
/// Focus is owned by that screen rather than held privately here, which is what
/// lets a tap outside this view clear it.
struct GramAmountField: View {
    @Binding var text: String
    let quickOptions: [Int]
    let identifierPrefix: String
    @FocusState.Binding var isFocused: Bool
    let onTextChange: () -> Void
    let onCommit: () -> Void
    let onQuickOption: (Int) -> Void

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
            // The box is what takes the tap, not the field inside it — the
            // field is at zero opacity until focused, and a journey cannot tap
            // something invisible.
            .accessibilityIdentifier("\(identifierPrefix).amountBox")

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

extension View {
    /// Lets a tap anywhere on screen put the grams keypad away.
    ///
    /// A number pad has no return key, so without this the only exit is the
    /// save button.
    ///
    /// This recognises the tap on the *window* rather than with an
    /// `onTapGesture` on the scroll content, which is what shipped first and
    /// what only ever worked in the simulator. A gesture inside a `ScrollView`
    /// has to win arbitration against the scroll pan: a synthesised click does
    /// not move at all and wins every time, while a real thumb drifts a few
    /// points on the way up and the pan takes the touch instead. Recognising on
    /// the window sidesteps the arbitration — the recogniser allows every other
    /// one to run alongside it and does not swallow touches, so the field, the
    /// shortcuts and the save button all still see their own.
    ///
    /// Attach it once per screen that owns a grams field; the modifier is only
    /// a probe for the window, so where on the screen it sits does not matter.
    func dismissesGramKeypadOnTap(_ isFocused: FocusState<Bool>.Binding) -> some View {
        background(
            KeypadDismissRecogniser(isKeypadUp: isFocused.wrappedValue) {
                isFocused.wrappedValue = false
            }
        )
    }
}

/// Installs a window-wide tap recogniser that resigns the grams keypad.
///
/// Nothing is drawn and no touch is consumed — the view exists to find the
/// window, and the recogniser lives there for as long as the screen does.
private struct KeypadDismissRecogniser: UIViewRepresentable {
    let isKeypadUp: Bool
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let probe = ProbeView()
        probe.isUserInteractionEnabled = false
        // The window is not known when the view is made, only when it is put
        // into the hierarchy.
        probe.onMoveToWindow = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return probe
    }

    func updateUIView(_ probe: UIView, context: Context) {
        context.coordinator.isKeypadUp = isKeypadUp
        context.coordinator.dismiss = dismiss
        context.coordinator.attach(to: probe.window)
    }

    static func dismantleUIView(_ probe: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class ProbeView: UIView {
        var onMoveToWindow: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onMoveToWindow?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isKeypadUp = false
        var dismiss: () -> Void = {}

        private weak var window: UIWindow?

        private lazy var recogniser: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            // Everything else still gets the touch: buttons fire, the field
            // takes focus, the scroll view scrolls.
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            return tap
        }()

        func attach(to window: UIWindow?) {
            guard let window, window !== self.window else { return }
            detach()
            window.addGestureRecognizer(recogniser)
            self.window = window
        }

        func detach() {
            window?.removeGestureRecognizer(recogniser)
            window = nil
        }

        @objc private func handleTap() {
            // With the keypad down there is nothing to dismiss, and staying out
            // of the way matters: the tap that *raises* the keypad is seen here
            // first, and clearing focus then would fight the field for it.
            guard isKeypadUp else { return }
            dismiss()
        }

        func gestureRecognizer(
            _ recogniser: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ recogniser: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            // A tap on the field itself is the user placing the caret, not
            // asking for the keypad to go.
            var view = touch.view
            while let candidate = view {
                if candidate is UITextInput { return false }
                view = candidate.superview
            }
            return true
        }
    }
}
