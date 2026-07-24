# Issue 77 simulator evidence

Captured from the final Debug build on iPhone 17 Pro Max after restacking
directly onto `main` (`ebf2506465b04563d3b14b02d1aef56f008166e1`).
The review state uses Accessibility XXXL so the ordered components expanded
from the authored “Breakfast Bowl” Meal remain legible at the largest Dynamic
Type size.

- `01-suggestions-before-typing.jpg`: deterministic local suggestions shown
  before search input alongside final Favorites and text-first Meals discovery.
- `02-multi-item-review-axxxl.jpg`: the authored Meal’s ordered component
  snapshots expanded into the fixed caller destination at the largest
  accessibility Dynamic Type size, using the native drill-in portion editor
  flow and the final “Log 3 Items” action.
- `03-recoverable-partial-state.jpg`: explicit recovery choices for a partially
  persisted multi-add batch after an interrupted commit, distinct from the
  removed partial-copy UX.
