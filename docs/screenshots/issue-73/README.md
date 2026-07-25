# Issue 73 simulator evidence

Captured from the Debug build on an iPhone 17 Pro simulator running iOS 26.5.
The fixture host is Debug-only and exercises the real barcode recovery and
reconciliation services with deterministic provider outcomes.

| File | State verified |
| --- | --- |
| `01-unknown-barcode-recovery.jpg` | Exact normalized barcode is shown with name search still available and a direct manual-food recovery action. |
| `02-manual-food-prefilled-barcode.jpg` | The unknown-barcode action opens manual creation with the normalized barcode prefilled. |
| `03-manual-food-accessibility-xxxl.jpg` | Manual recovery remains readable at Accessibility XXXL without splitting the barcode into narrow columns. |
| `04-incomplete-provider-food.jpg` | An incomplete community product has a passive warning and a private edit action. |
| `05-private-correction-form.jpg` | Provider values are editable privately; missing protein and fat remain empty while the barcode stays attached. |
| `06-silent-provider-completion.jpg` | A matching refresh preserves the user name and explicit-zero overlay while silently filling missing provider nutrition. No comparison or refresh prompt appears. |
| `06b-silent-completion-field-origins.jpg` | The materialized values show provider-filled protein alongside the preserved user-entered zero for fat. |
| `07-offline-local-fallback.jpg` | A simulated offline provider request returns the latest safe personal materialization without presenting not-found or requiring an action. |
| `08-unknown-recovery-accessibility-xxxl.jpg` | The unknown-product recovery state and name search remain readable and usable at Accessibility XXXL. |

The screenshots were inspected after capture. The first Accessibility XXXL
manual-form pass exposed an overly compressed barcode row; the layout was
changed to stack its label and value at accessibility sizes, and screenshots 03
and 08 are the post-fix audit captures.
