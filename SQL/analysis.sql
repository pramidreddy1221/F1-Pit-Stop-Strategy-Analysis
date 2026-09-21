-- F1 Pit Stop Strategy Analysis — Piece 2 (SQL), 2011-2024, db: f1

CREATE TABLE drivers (
    driverId INT PRIMARY KEY, driverRef VARCHAR(100), number INT, code VARCHAR(20),
    forename VARCHAR(50), surname VARCHAR(50), dob DATE, nationality VARCHAR(50), url TEXT
);

CREATE TABLE races (
    raceId INT PRIMARY KEY, year INT, round INT, circuitId INT, name VARCHAR(50), date DATE,
    time TIME, url TEXT, fp1_date DATE, fp1_time TIME, fp2_date DATE, fp2_time TIME,
    fp3_date DATE, fp3_time TIME, quali_date DATE, quali_time TIME, sprint_date DATE, sprint_time TIME
);

CREATE TABLE results (
    resultId INT PRIMARY KEY, raceId INT, driverId INT, constructorId INT, number INT, grid INT,
    position INT, positionText VARCHAR(20), positionOrder INT, points INT, laps INT, time VARCHAR(20),
    milliseconds INT, fastestLap INT, rank INT, fastestLapTime VARCHAR(20),
    fastestLapSpeed NUMERIC(10,2), statusId INT
);

-- pit_stops, constructors, circuits also loaded from the Kaggle CSVs (table definitions not included here)


-- Outlier check: milliseconds > 100000 = red-flag/safety-car artifacts, not slow stops (verify count on rerun)
SELECT COUNT(*) FROM pit_stops WHERE milliseconds > 100000;

-- Rule used everywhere below: WHERE milliseconds < 100000 excludes only those artifacts


-- 1. Stops per race by year — checks stop frequency is comparable across eras
SELECT year, COUNT(*), COUNT(*)::NUMERIC / COUNT(DISTINCT r.raceid) AS stops_per_race
FROM races r
JOIN pit_stops p ON p.raceid = r.raceid
GROUP BY year
ORDER BY year;

SELECT year, COUNT(*) FROM races GROUP BY year ORDER BY year;


-- 2. Base row-level query: stop duration + finishing position
SELECT s.position, p.duration, p.milliseconds
FROM results s
JOIN pit_stops p ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
WHERE year BETWEEN 2011 AND 2024;

-- 3. Correlation: single stop duration vs. finishing position -> +0.135 (weak, slower stop = worse finish)
-- (earlier run without the outlier filter gave -0.045; outliers were masking the relationship)
SELECT CORR(p.milliseconds, s.position)
FROM results s
JOIN pit_stops p ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
WHERE year BETWEEN 2011 AND 2024
  AND s.position IS NOT NULL
  AND p.milliseconds < 100000;


-- 4. Correlation: TOTAL pit time per driver-per-race vs. position -> +0.175 (weak, more time = worse finish)
SELECT CORR(sub.position, total_time) FROM
(
    SELECT p.driverId, p.raceId, s.position, SUM(p.milliseconds) AS total_time
    FROM pit_stops p
    JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
    JOIN races r ON r.raceId = s.raceId
    WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
    GROUP BY p.driverId, p.raceId, s.position
) AS sub;


-- 4b. Correlation: AVERAGE stop time per driver-per-race vs. position -> +0.142 (weak)
SELECT CORR(sub.position, avg_time) FROM
(
    SELECT p.driverId, p.raceId, s.position, AVG(p.milliseconds) AS avg_time
    FROM pit_stops p
    JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
    JOIN races r ON r.raceId = s.raceId
    WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
    GROUP BY p.driverId, p.raceId, s.position
) AS sub;


-- 5. Mean + stddev by constructor — consistency (stddev) vs. systemic slowness (mean)
-- HAVING >= 150: natural gap in stop-count distribution (73-149 vs 231+), keeps multi-season teams only
SELECT AVG(p.milliseconds), STDDEV(p.milliseconds), c.name
FROM pit_stops p
JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
JOIN constructors c ON c.constructorId = s.constructorId
WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
GROUP BY c.name
HAVING COUNT(*) >= 150
ORDER BY STDDEV(p.milliseconds) DESC;


-- 6. Mean + stddev by year — did pit stop time change over time?
SELECT AVG(p.milliseconds), STDDEV(p.milliseconds), r.year
FROM pit_stops p
JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
GROUP BY r.year
HAVING COUNT(*) >= 150
ORDER BY r.year DESC;


-- 7. Year-over-year change (window function: LAG) — 2013->2014 jump (+1295ms) stands out
SELECT year, avg_ms,
       avg_ms - LAG(avg_ms) OVER (ORDER BY year) AS yoy_change,
       LAG(avg_ms) OVER (ORDER BY year) AS prev_year_avg
FROM (
    SELECT AVG(p.milliseconds) AS avg_ms, STDDEV(p.milliseconds), r.year
    FROM pit_stops p
    JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
    JOIN races r ON r.raceId = s.raceId
    WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
    GROUP BY r.year
    HAVING COUNT(*) >= 150
) AS yearly
ORDER BY year;

-- 8. Mean + stddev by constructor per year — same logic as view V1 below
-- No HAVING: stop counts per team-season run 44-110 with no gap, so no noise to filter
SELECT c.name,
       r.year,
       AVG(p.milliseconds) AS avg_ms,
       STDDEV(p.milliseconds) AS stddev_ms,
       COUNT(*) AS stop_count
FROM pit_stops p
JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
JOIN constructors c ON c.constructorId = s.constructorId
WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
GROUP BY c.name, r.year
ORDER BY c.name, r.year;


-- ===== Views for Power BI =====

-- V1. Stats per constructor per year (from query 8) — feeds the yearly trend line (weighted average)
--     and the "pit stops analyzed" and "2013 -> 2014 change" cards
CREATE OR REPLACE VIEW vw_constructor_year_stats AS
SELECT c.name as constructor,
       r.year,
       AVG(p.milliseconds) AS avg_ms,
       STDDEV(p.milliseconds) AS stddev_ms,
       COUNT(*) AS stop_count
FROM pit_stops p
JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
JOIN constructors c ON c.constructorId = s.constructorId
WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
GROUP BY c.name, r.year;


-- V2. Pit time per driver per race, DNFs excluded (from query 4) — feeds pit time vs. finishing position
CREATE OR REPLACE VIEW vw_driver_race_pit_times AS
SELECT p.driverId, p.raceId, s.position, SUM(p.milliseconds) AS total_pit_ms, AVG(p.milliseconds) AS avg_stop_ms, COUNT(*) AS stop_count,r.year
FROM pit_stops p
JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000 AND s.position IS NOT NULL
GROUP BY p.driverId, p.raceId, s.position,r.year;

-- V3: full-window constructor stats (replicates query 5) — feeds constructor comparison visual
CREATE VIEW vw_constructor_stats AS
SELECT c.name AS constructor,
       AVG(p.milliseconds) AS avg_ms,
       STDDEV(p.milliseconds) AS stddev_ms,
       COUNT(*) AS stop_count
FROM pit_stops p
JOIN results s ON p.driverId = s.driverId AND p.raceId = s.raceId
JOIN races r ON r.raceId = s.raceId
JOIN constructors c ON c.constructorId = s.constructorId
WHERE year BETWEEN 2011 AND 2024 AND p.milliseconds < 100000
GROUP BY c.name
HAVING COUNT(*) >= 150;