# Netflix Content Analysis: 2015–2021

An end-to-end data analysis project exploring Netflix catalog composition, growth trends, and genre dynamics using **MySQL** for data cleaning and EDA, and **Tableau** for visualization.

---

## Project Overview

This project analyzes a dataset of 8,807 Netflix titles to uncover how Netflix has built and evolved its content catalog over time. The analysis covers catalog composition by content type, genre dominance, year-over-year growth trends, and the fastest growing genres between 2015 and 2021.

The project is structured in two phases:
- **Phase 1 — SQL:** Data cleaning, normalization, and exploratory data analysis in MySQL
- **Phase 2 — Tableau:** Dashboard visualization of key insights

---

## Key Insights

- **Movies dominate the catalog** at 69.6% (6,131 titles) vs TV Shows at 30.4% (2,676 titles)
- **International Movies is the top genre** with over 2,500 titles — nearly double the next genre
- **Netflix peaked in 2019** adding 2,014 new titles, followed by a decline in 2020–2021 likely linked to COVID-19 production disruptions
- **Both content types follow the same growth pattern** — Movies and TV Shows both peaked in 2019 and declined together, maintaining a roughly 70/30 split throughout
- **Romantic TV Shows grew fastest** at 699% average YoY growth, with International TV Shows and Crime TV Shows close behind — TV genres dominate the fastest growing list, signaling Netflix's push into original TV content

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| MySQL 9.5 | Data cleaning, normalization, EDA |
| Tableau Desktop Public Edition | Dashboard visualization |
| Python (optional) | CSV re-export for encoding fix |

---

## Data Source

**Netflix Movies and TV Shows** — publicly available dataset sourced from Kaggle, containing 8,807 titles with metadata including type, genre, country, rating, duration, and date added to Netflix.

Original dataset: [Netflix Movies and TV Shows on Kaggle](https://www.kaggle.com/datasets/shivamb/netflix-shows)

---

## Project Structure

```
netflix-analysis/
│
├── README.md
│
├── data/
│   ├── netflix_titles.csv                  ← Original raw dataset (never modified)
│   ├── netflix_titles_clean_updated.csv    ← Cleaned working table (8,807 rows)
│   ├── netflix_genres.csv                  ← Genre junction table (19,323 rows)
│   └── netflix_countries.csv              ← Country junction table (10,012 rows)
│
├── sql/
│   └── Netflix_Project_cleaning_eda.sql   ← Full SQL script: cleaning + EDA
│
└── dashboard/
    ├── netflix_dashboard.png              ← Dashboard screenshot
    └── netflix_dashboard.pdf             ← Dashboard PDF export
```

---

## SQL Phase Summary

The SQL phase covered the following steps:

**Data Cleaning:**
- Duplicate check on `show_id` and composite keys
- Fixed rating ↔ duration swap for 3 Louis C.K. rows
- Parsed `date_added` string into a clean `DATE` column
- Extracted `duration_int` and `duration_unit` from the raw duration string
- Filled missing values: director → `"Unknown"`, cast → `"Not Listed"`, country → `"Not Listed"`, rating → mode (`TV-MA`)
- Denormalized `listed_in` into `netflix_genres` junction table (19,323 rows)
- Denormalized `country` into `netflix_countries` junction table (10,012 rows)

**EDA Queries:**
- Movie vs TV Show split with percentage of total
- Rating distribution with frequency and percentage
- Genre frequency ranking
- Country production volume ranking
- Year-over-year catalog growth (2015+) with cumulative totals and YoY growth %
- YoY growth split by content type using `PARTITION BY type`
- Average movie duration by rating (MIN, MAX, AVG)
- Content duration differences across genres split by type
- Genre specialisation by country — top genre per country using `ROW_NUMBER() PARTITION BY country`
- Average YoY growth rate by genre using `LAG()` window function (top 20 fastest growing genres)

---

## Visualization Phase Summary

Built in Tableau Desktop Public Edition using three connected data sources joined on `show_id`:

- `netflix_titles_clean_updated.csv` — primary table
- `netflix_genres.csv` — left joined for genre analysis
- `netflix_countries.csv` — left joined for country analysis

**Charts built:**
1. Content Type Split — donut chart
2. Genre Dominance — horizontal bar with red gradient
3. Year-over-Year Catalog Growth — line chart (2015–2021)
4. Movie vs TV Shift — dual line chart by content type
5. Fastest Growing Genres — horizontal bar with orange gradient

---

## Important Technical Notes

**Data integrity:**
- `netflix_titles` is the raw original — never modified at any point
- All cleaning and analysis is done exclusively on `netflix_titles_clean`
- 3 rows (Louis C.K. specials: `s5542`, `s5795`, `s5814`) have `NULL` rating intentionally — their rating values were swapped into the `duration` column in the source data and corrected during cleaning
- Empty strings and NULLs are treated separately — always check both when validating data quality

**Column usage guidelines:**
- For genre analysis, always use `netflix_genres` — `listed_in` in the main table contains comma-separated values and produces incorrect `GROUP BY` counts
- For country analysis, always use `netflix_countries` — same reason as above
- Use `date_added_clean`, `year_added`, and `month_added` for date-based analysis — not the raw `date_added` string
- Use `duration_int` + `duration_unit` for numeric duration analysis — never average `duration_int` across both Movies and TV Shows since units differ (`min` vs `Season`)
- Exclude `'Unknown'` from director filters and `'Not Listed'` from country filters in any analysis

**Row count expectations:**
- `netflix_genres` has 19,323 rows and `netflix_countries` has 10,012 rows — both exceed 8,807 because many titles have multiple genres/countries. This is correct and expected.
- YoY growth queries are filtered to `year_added >= 2015` to avoid misleading percentages from low-volume early years (as few as 1–3 titles per year before 2013)

---

## Author

**Yufan (Leo) Xie**
[LinkedIn](https://www.linkedin.com/in/yufan-xie-leo/)
