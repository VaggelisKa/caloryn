# Issue #69 UI evidence

Captured on an iPhone 17 Pro simulator running iOS 26.4.

| State | Evidence |
| --- | --- |
| My Foods keeps Favorites at the top, hides duplicate rows, and limits the collapsed section to five | ![Collapsed My Foods favorites](my-foods-favorites-collapsed.jpg) |
| A leading swipe on an eligible custom food exposes Favorite | ![Favorite leading swipe](add-favorite-swipe.jpg) |
| A trailing swipe on a favorite exposes Remove Favorite beside Delete | ![Remove favorite and delete trailing swipe](remove-favorite-swipe.jpg) |
| An existing custom food can be favorited from the edit toolbar beside Save | ![Favorite control in the custom food edit toolbar](favorite-edit-toolbar.jpg) |
| Quick logging shows five compact favorites, remembered amounts, and no redundant destination label | ![Collapsed quick-log favorites](quick-log-collapsed.jpg) |
| Show all expands large favorite collections and Show less collapses them again | ![Expanded quick-log favorites](quick-log-expanded.jpg) |

The no-history path reuses the app's standard portion input sheet. The logged-food
editor deliberately has no favorite control because favorites belong to custom food
definitions, not individual log entries.
