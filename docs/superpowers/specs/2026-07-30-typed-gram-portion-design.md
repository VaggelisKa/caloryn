# Typing grams instead of spinning them

## The complaint

Reaching 340 g from 100 g on the gram wheel is forty-eight rows of spinning.
Users reported this as the most annoying part of logging. A slice count never
goes past ten, which is exactly what a wheel is good at — so the fix is not to
replace the picker, it is to stop using one control for two different jobs.

## What changes

Grams become a typed field with three shortcut amounts beneath it. Everything
else stays: the serving-count wheel, the recipe-fraction wheel, and the unit
wheel that switches between them. Both screens that log grams get the field —
`PortionPickerView` and `MultiAddPortionEditorView`.

## Layout

The amount column swaps by mode; the unit wheel is unchanged beside it.

```
GRAMS MODE                        PORTION MODE (as before)
┌──────────────────┬───────────┐  ┌──────────────────┬───────────┐
│  [  180  ] g     │   grams   │  │        1         │   grams   │
│                  │ ‹ bowl  › │  │      ‹ 2 ›       │ ‹ bowl  › │
│  (90)(180)(270)  │           │  │        3         │           │
└──────────────────┴───────────┘  └──────────────────┴───────────┘
```

A food with no second unit gets no unit column at all — the field already reads
"180 g", so a static "grams" caption beside it only repeated itself while
squeezing the field to 60% of the card.

## Model — `PortionSelection`

The wheel's constants existed because it was a materialized `Array`: 2,000 rows
at 10 kg, and an unbounded serving size meant an unbounded array. Typing removes
that reason.

| Removed | Replaced by |
|---|---|
| `gramStep: Int` | `gramsInput: String` — the raw field text |
| `gramStepChanged()` | `commitGramsInput()` — parse, clamp, write, reformat |
| `gramOptions: [Int]` | `quickGramOptions: [Int]` — three chips |
| `gramStepSize`, `minimumGramOption`, `gramOptionLimit`, `normalizedGramStep` | `minimumGrams = 1`, `maximumGrams = 10_000` |

`commitGramsInput()` takes whole grams clamped to 1…10000. Anything the field
cannot mean — empty mid-edit, a stray minus, a pasted word — leaves the portion
alone and snaps the text back to what is actually logged. `portionGrams` stays a
`Double`, so a fractional portion scaled in from a multi-add copy displays its
fraction rather than being silently rounded.

Shortcuts scale to what the food knows about itself: multiples of a countable
serving, quarter/half/whole of a recipe, and round numbers (50 · 100 · 200) for
a food with neither. A serving size so absurd that every multiple clamps to the
ceiling falls back to the round numbers rather than showing "10000" three times
— `defaultServingG` comes from the food API and from a free-text field.

### One behaviour change, on purpose

Switching from slices to grams no longer rounds. The gram wheel could only stop
on a multiple of five, so `modeChanged()` had to snap the portion to a row it
could show — two 33 g servings became 65 g. A field has no rows, so it keeps 66.
`PortionSelectionTests` pins this.

## Committing on the way out

The keypad has no dismiss key and the save button sits in a bottom safe-area
inset, so both screens commit the field in `save()` before writing. Without it a
portion typed and never dismissed would log the previous value. `GramAmountField`
also carries a keyboard toolbar "Done", since the number pad would otherwise
cover the only way off the screen.

## Testing

`PortionSelectionTests` covers parse, clamp, reject, the shortcuts for each food
shape, and the no-longer-rounding mode switch. `NonFiniteNumberSafetyTests`
keeps its guard on absurd serving sizes, now against the shortcut rule.

No UI journey touched the wheel — they assert on calories and save — so the E2E
net needs no change. Both screens are captured by `theme-screenshots.sh` and
were checked in light and dark.
