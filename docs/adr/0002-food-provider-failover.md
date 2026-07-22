# ADR 0002: Bounded food-provider failover and provenance

## Status

Accepted.

## Context

Food search and barcode lookup can use the Caloryn API or Open Food Facts. A
single configured provider made transient failures dead ends, while saved and
logged foods did not retain enough information to explain their source or
nutrition completeness.

## Decision

The default policy is an ordered, bounded pair:

1. Caloryn API (primary)
2. Open Food Facts (secondary)

Each provider is attempted at most once. The policy removes a secondary that
duplicates the primary, so it cannot loop or issue duplicate attempts.

### Error and fallback rules

| Outcome | Fallback | User outcome |
| --- | --- | --- |
| Success with usable results | No | Show results |
| Not found / empty result | Yes | Use secondary; report not found only if both are not found |
| Provider response has no usable name/calories or cannot decode | Yes | Use secondary; otherwise report invalid nutrition data |
| Timeout, connection loss, HTTP 408, or HTTP 5xx | Yes | Use secondary; otherwise report unavailable |
| Cancellation | No | End silently for view-driven work |
| Device offline | No | Ask the user to reconnect |
| HTTP 401/403 | No | Report service access unavailable |
| HTTP 429 | No | Ask the user to try later; do not route around rate limits |
| Invalid query/barcode or other HTTP 4xx | No | Ask the user to change the input |

Barcode input is accepted only when it contains 4–32 ASCII digits (`0`–`9`).
Validation happens before telemetry or a provider request; Unicode numerals are
rejected as invalid input.

When two eligible attempts fail, the final error stays conservative. A result
is only “not found” when every completed attempt is not found. If one provider
was unavailable, the final state is unavailable because absence was not
confirmed across both providers.

### Reconciliation

Results use normalized barcode as the primary identity. Products without a
barcode use normalized product name plus brand. Stable source order is
preserved, but a later duplicate replaces an earlier duplicate when it has
strictly more populated nutrition, serving, brand, or Nutri-Score fields.
Equal-quality duplicates keep the earlier (primary) result.

### Provenance and completeness

Lookup results carry two separate concepts:

- the operational provider used for the request;
- the user-facing data source (Caloryn catalog or Open Food Facts community).

Completeness is `complete` when calories, protein, carbohydrates, and fat are
present, `partial` when calories are usable but one of those core macros is
missing, and `unknown` for legacy or unusable data. Partial data is retained so
the user can still log it, but the UI explicitly warns that missing values
appear as zero and should be checked against packaging.

Provider, source, completeness, and fallback-recovery state are stored on
`FoodItem`, copied to `RecipeIngredient`, and snapshotted on `FoodLogEntry`.
All new SwiftData columns are optional raw fields. Lightweight migration leaves
legacy rows nil, and computed accessors report `unknown` instead of inventing
historical provenance. A legacy log entry never falls back to the mutable
provenance on its linked food.

The same optional provenance fields travel in final-main’s immutable
`FoodLogEntrySnapshot` payload. That keeps authored Meals, explicit meal/snack
routing, multi-add review and retry, and copy flows faithful to the source that
was recorded even if the linked food is later edited or deleted. Older encoded
snapshots decode with those fields absent and therefore remain `unknown`.

Saving nutrition through the manual editor makes the user the source of the
current values. It clears provider and fallback attribution and recomputes
completeness from the three core macro fields. A cleared field is `partial`,
while an explicitly entered zero is a present value. Log entries snapshot that
edited provenance, so later edits cannot rewrite the warning shown for history.

### Operational telemetry and privacy

Each provider attempt emits only:

- operation (`search` or `barcode`);
- provider;
- outcome;
- latency class (`fast`, `moderate`, or `slow`);
- attempt number;
- whether it was the fallback and whether that fallback succeeded.

The event type has no field capable of carrying a query, barcode, food name,
brand, nutrition value, or response payload. Logs mark every included enum and
number as public because the schema is deliberately payload-free.

## Consequences

Lookups can issue one additional request after an eligible primary failure.
Cancellation, offline state, authentication, validation, and rate limits never
fan out. Saved and historical entries can explain source quality without
depending on a live food relationship, while legacy data remains explicitly
unknown. Search rows stay focused on product selection; the pre-log portion
screen contains the source, fallback, and completeness explanation when it is
relevant. Barcode misses use a message-only empty state because name search is
already the primary control on the screen.
