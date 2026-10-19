import SwiftUI

struct GramAmountField: View {
    @Binding var text: String
    let quickOptions: [Int]
    let identifierPrefix: String
    @FocusState.Binding var isFocused: Bool
    let onTextChange: () -> Void
    let onCommit: () -> Void
    let onQuickOption: (Int) -> Void
    let onStep: (PortionSelection.GramStep) -> Void
    var quickOptionLabel: (Int) -> String = { "\($0) g" }

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title3) private var unitSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var stepperHeight: CGFloat = 68
    @ScaledMetric(relativeTo: .body) private var stepButtonSize: CGFloat = 48

    private var pillHeight: CGFloat { min(stepperHeight, 80) }
    private var buttonDiameter: CGFloat { min(stepButtonSize, 60) }
    private var amountFontSize: CGFloat { min(numberSize, 52) }
    private var unitFontSize: CGFloat { min(unitSize, 28) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                stepButton(.less)
                amountBox
                stepButton(.more)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: pillHeight)
            .background(CalorynTheme.backgroundTertiary, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        isFocused ? CalorynTheme.accent : CalorynTheme.separator,
                        lineWidth: isFocused ? 1.2 : CalorynTheme.hairlineWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isFocused)

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

            Text("g")
                .font(CalorynTypeface.fixed(size: unitFontSize, weight: .semibold))
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: buttonDiameter)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .accessibilityIdentifier("\(identifierPrefix).amountBox")
    }

    private func stepButton(_ step: PortionSelection.GramStep) -> some View {
        Button {
            isFocused = false
            if stepChangesAmount(step) { CalorynHaptics.selectionChanged() }
            onStep(step)
        } label: {
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
            isFocused = false
            if !isSelected(grams) { CalorynHaptics.selectionChanged() }
            onQuickOption(grams)
        } label: {
            Text(quickOptionLabel(grams))
                .calorynChip(isSelected: isSelected(grams))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifierPrefix).quickGrams.\(grams)")
        .accessibilityLabel("\(grams) grams")
        .accessibilityAddTraits(isSelected(grams) ? .isSelected : [])
    }

    private func stepChangesAmount(_ step: PortionSelection.GramStep) -> Bool {
        guard let grams = PortionSelection.parsedGrams(text) else { return true }
        return PortionSelection.stepped(Double(grams), step) != Double(grams)
    }

    private func isSelected(_ grams: Int) -> Bool {
        text == "\(grams)"
    }
}

extension View {
    func dismissesGramKeypadOnTap(_ isFocused: FocusState<Bool>.Binding) -> some View {
        background(
            KeypadDismissRecogniser(isKeypadUp: isFocused.wrappedValue) {
                isFocused.wrappedValue = false
            }
        )
    }
}

private struct KeypadDismissRecogniser: UIViewRepresentable {
    let isKeypadUp: Bool
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let probe = ProbeView()
        probe.isUserInteractionEnabled = false
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
            var view = touch.view
            while let candidate = view {
                if candidate is UITextInput { return false }
                view = candidate.superview
            }
            return true
        }
    }
}
