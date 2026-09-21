# F1 Pit Stop Strategy Analysis — Requirements

**Business question:** Does pit stop speed correlate with race finishing
position, and have pit stop times changed over the years? (2011–2024,
based on FIA pit stop timing data availability)

**Metric used:** "Pit stop time" in this project means **pit lane time**,
the FIA-published time from pit entry to pit exit, not the 2–3 seconds the
car is stationary. This is why values are around 20–25 seconds per stop.

**Who cares:** Team strategists and race engineers — to evaluate whether
pit crew performance is a lever worth investigating further.

**Decision informed:** Whether pit stop execution is a meaningful
differentiator in race outcomes, and which constructors are lagging —
including whether their issue looks like an execution/consistency problem
(high variance in stop times) or a systemic/process problem (consistently
slow). This narrows where a deeper investigation should start. Root cause
(training vs. equipment) is not answerable from this data alone.

**Definition of done:** A single-page Power BI dashboard, connected to the
PostgreSQL database, showing:
1. Average total pit lane time per race by finishing position (positions 1–20)
2. Average pit lane time per season, 2011–2024
3. Constructor comparison over the full 2011–2024 window: average pit lane
   time (speed) vs. standard deviation (consistency)
4. Headline cards: pit stops analyzed, correlation between pit time and
   finishing position, and the 2013→2014 change in pit lane time

A viewer should be able to identify which teams lag on pit execution and
whether it looks like a consistency issue or a raw-speed issue.

**Scope change:** The original plan was per-constructor trend lines by
season. With 17+ constructors, the lines overlapped into an unreadable
chart and hid the constructor findings. This was replaced with a
full-window speed vs. consistency scatter (item 3), plus a single overall
season trend (item 2) to answer the second half of the business question.

## Limitations

- **Pit lane time is not crew speed alone.** It also depends on each
  circuit's pit lane length and speed limit. The calendar changes every
  season, so part of the year-to-year movement may reflect which tracks
  were raced rather than how fast crews worked.
- **Correlation, not causation.** The pit time vs. finishing position
  correlation is weak (+0.175). Slower teams often have slower cars as
  well as slower crews, so pit time cannot be isolated as the cause of
  worse finishes.
- **Constructor renames are kept as separate teams** (e.g., Toro Rosso and
  AlphaTauri, Renault and Alpine F1 Team), as recorded in the dataset.
  Merging them would require judgment calls about team continuity.
- **Small constructors excluded from the comparison.** Only teams with 150+
  pit stops are included in the constructor comparison, based on a natural
  gap in stop counts (73–149 vs. 231+). This keeps multi-season teams only.
- **Outlier stops excluded.** Stops of 100 seconds or longer are removed,
  as they don't represent normal pit stops.
- **DNFs excluded from the finishing-position analysis.** A driver without
  a finishing position cannot be placed on that axis.
- **Positions 21–24 excluded from the finishing-position chart.** Only the
  2011–2014 and 2016 seasons had grids larger than 20 cars, and these
  positions have 1–26 rows each, too few to be reliable.
