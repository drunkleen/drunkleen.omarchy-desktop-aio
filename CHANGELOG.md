# Changelog

## 1.3.6

- Fixed the settings lifecycle reported in Marketplace issue #15253. Weather,
  Components & Layout, and Advanced unload when inactive, and hidden text and
  number editors are no longer instantiated.
- Leaving Weather cancels pending city searches and clears their suggestions.
  Advanced keeps the typed import/export path across category changes.
- Improved desktop dragging and resizing so fast pointer movement outside the
  original widget bounds stays tracked until release or cancellation.
- Improved component dragging and stacking. Overlapping components stay
  selectable, and dragging preserves the initial target and saves on release.
- Added **Divider** as an independent component with visibility, placement,
  stacking, reset, and import/export support.
- Existing six-component layouts keep saved positions and relative stacking.
  The divider defaults to visible and is inserted behind the existing components.
  Its visibility is independent of Weather and Clock.
- Added runtime regressions for settings lifecycle and placement. The runtime
  runner now detects Quickshell category-prefixed errors.
