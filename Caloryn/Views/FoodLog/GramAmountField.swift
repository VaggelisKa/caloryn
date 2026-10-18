import SwiftUI

/// A typed weight in grams inside a stepper pill (minus and plus move it ten grams),
/// with a row of shortcut amounts beneath it.
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
    /// The stepper's minus and plus. The step itself is `PortionSelection.gramStepSize`.
    let onStep: (PortionSelection.GramStep) -> Void
    /// A shortcut's label: its weight, or the food's own serving with it ("1 pot, 150 g").
    /// The chip's identifier stays keyed on the grams.
    var quickOptionLabel: (Int) -> String = { "\($0) g" }

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title3) private var unitSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var stepperHeight: CGFloat = 68
    @ScaledMetric(relativeTo: .body) private var stepButtonSize: CGFloat = 48

    // The pill grows with Dynamic Type, but only so far: both buttons and the amount have
    // to share one line on a phone. Uncapped, the buttons alone reached about 110pt each at
    // the accessibility sizes and covered the "g" beside the number.
    private var pillHeight: CGFloat { min(stepperHeight, 80) }
    private var buttonDiameter: CGFloat { min(stepButtonSize, 60) }
    private var amountFontSize: CGFloat { min(numberSize, 52) }
    private var unitFontSize: CGFloat { min(unitSize, 28) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The stepper pill: a `backgroundTertiary` capsule with round minus and plus buttons at
            // its ends and the typed amount between them. The buttons are siblings of
            // the amount box, not children of it — an identifier on a container is
            // inherited by everything inside, so the box's would have named the buttons
            // too, and a journey tapping "amountBox" could have landed on minus.
            HStack(spacing: 0) {
                stepButton(.less)
                amountBox
                stepButton(.more)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: pillHeight)
            .background(CalorynTheme.backgroundTertiary, in: Capsule())
            .overlay {
                // A well, not a card: a hairline edge, and ink while it is being typed in.
                Capsule()
                    .strokeBorder(
                        isFocused ? CalorynTheme.accent : CalorynTheme.separator,
                        lineWidth: isFocused ? 1.2 : CalorynTheme.hairlineWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isFocused)

            // One row of shortcuts, or one per line when a large text size will not fit
            // them side by side.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(quickOptions, id: \.self) { grams in
                        quickOption(grams)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(quickOptions, id: \.self) { grams in
                        quickOption(grams)
                    }
                }
            }
        }
        .onChange(of: text) { onTextChange() }
        .onChange(of: isFocused) { _, focused in
            if !focused { onCommit() }
        }
    }

    private var amountBox: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
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
            .font(CalorynTheme.heroNumber(size: amountFontSize))
            .tracking(-amountFontSize * 0.01)
            .foregroundStyle(CalorynTheme.textPrimary)
            .fixedSize()

            // Left visible to accessibility on purpose: the box's identifier is inherited
            // by its children, the field keeps its own, and this label is what then
            // carries `amountBox` for a journey to tap.
            Text("g")
                .font(CalorynTypeface.fixed(size: unitFontSize, weight: .semibold))
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: buttonDiameter)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        // The box is what takes the tap, not the field inside it — the
        // field is at zero opacity until focused, and a journey cannot tap
        // something invisible.
        .accessibilityIdentifier("\(identifierPrefix).amountBox")
    }

    private func stepButton(_ step: PortionSelection.GramStep) -> some View {
        Button {
            // Focus goes first, as for a shortcut: the rolling number is the unfocused
            // `Text`, and the step should land on it rather than on the hidden field.
            isFocused = false
            onStep(step)
        } label: {
            // The board's round white button on the pill, not glass: the stepper is content,
            // and glass on the `backgroundTertiary` pill read as a dark hole in dark mode. The hairline
            // ring is what still separates it from the pill there, where the card and the
            // surface are the same colour.
            Image(systemName: step == .more ? "plus" : "minus")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.accent)
                .frame(width: buttonDiameter, height: buttonDiameter)
                .background(CalorynTheme.backgroundSecondary, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                }
                .shadow(color: CalorynTheme.shadow, radius: 4, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(PortionSelection.gramStepSize.truncatedSafely) grams \(step == .more ? "more" : "less")"
        )
        .accessibilityIdentifier("\(identifierPrefix).\(step == .more ? "stepUp" : "stepDown")")
    }

    private func quickOption(_ grams: Int) -> some View {
        Button {
            // Focus goes first: the rolling number is the unfocused `Text`, so
            // changing the value before yielding focus would land it on the
            // field and skip the animation.
            isFocused = false
            onQuickOption(grams)
        } label: {
            // Ink marks the chosen chip and nothing else here: the calorie readout
            // above, in the meal's colour, is what should catch the eye.
            Text(quickOptionLabel(grams))
                .calorynChip(isSelected: isSelected(grams))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifierPrefix).quickGrams.\(grams)")
        .accessibilityLabel("\(grams) grams")
        .accessibilityAddTraits(isSelected(grams) ? .isSelected : [])
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
