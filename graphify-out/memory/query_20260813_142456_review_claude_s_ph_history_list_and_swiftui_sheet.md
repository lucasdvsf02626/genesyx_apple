---
type: "query"
date: "2026-08-13T14:24:56.643175+00:00"
question: "Review Claude's pH history list and SwiftUI sheet-state race fix"
contributor: "graphify"
outcome: "useful"
source_nodes: ["PhReading", "LogHistoryView", "PhTrackerCard"]
---

# Q: Review Claude's pH history list and SwiftUI sheet-state race fix

## Answer

Expanded from original query via vocab: [tracker, sheet, history, edit, reading, mode, log]. Live source confirms PhTrackerSection now uses one PhSheetMode item as the sheet source of truth, passing mode.reading directly to PhLogSheet. The older-history UI test opens row 2 as Edit pH reading with value 6.3 and Delete. Repository tests already cover update/delete and tombstone sync; final completion still depends on the full suite passing. The pre-existing docs/CHANGE_LIST_PLAN.md diff is intentional and must not be reverted.

## Outcome

- Signal: useful

## Source Nodes

- PhReading
- LogHistoryView
- PhTrackerCard