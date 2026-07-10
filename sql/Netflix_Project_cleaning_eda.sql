-- Table Setup
CREATE DATABASE netflix_db;
USE netflix_db;
CREATE TABLE netflix_titles (
    show_id      VARCHAR(10)   PRIMARY KEY,
    type         VARCHAR(10),
    title        VARCHAR(200),
    director     VARCHAR(300),
    cast         TEXT,
    country      VARCHAR(200),
    date_added   VARCHAR(50),
    release_year YEAR,
    rating       VARCHAR(20),
    duration     VARCHAR(20),
    listed_in    VARCHAR(200),
    description  TEXT
);

SET GLOBAL local_infile = 1;
SHOW GLOBAL VARIABLES LIKE 'local_infile';
LOAD DATA LOCAL INFILE '/Users/leoxie/Desktop/Netflix Project/netflix_titles.csv'
INTO TABLE netflix_titles
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE netflix_titles;

SELECT COUNT(*) FROM netflix_titles;

-- Data Cleaning
# Remove Duplicates
SELECT show_id, COUNT(*) as count
FROM netflix_titles
GROUP BY show_id
HAVING COUNT(*) > 1;

SELECT title, type, release_year, COUNT(*) as count
FROM netflix_titles
GROUP BY title, type, release_year
HAVING COUNT(*) > 1;

-- Check rating column for values that look like durations
SELECT show_id, title, rating, duration
FROM netflix_titles
WHERE rating LIKE '%min%'
   OR rating LIKE '%Season%';

-- Check duration column for values that look like ratings
SELECT show_id, title, rating, duration
FROM netflix_titles
WHERE duration IN ('G','PG','PG-13','R','NC-17',
                   'TV-Y','TV-Y7','TV-G','TV-PG','TV-14','TV-MA','NR','UR')
   OR duration REGEXP '^[A-Z]{1,5}-?[0-9]{0,2}$';

-- Swap the values by identifying the problematic rows
UPDATE netflix_titles
SET 
    duration = rating,
    rating = NULL
WHERE show_id IN ('s5542', 's5795', 's5814');

-- Verify the fix
SELECT show_id, title, rating, duration
FROM netflix_titles
WHERE title LIKE '%Louis C.K%';

-- Create a copy for further cleaning
CREATE TABLE netflix_titles_clean AS
SELECT * FROM netflix_titles;

-- Verify the copy
SELECT COUNT(*) FROM netflix_titles_clean;

-- Normalization of date_added
SELECT date_added
FROM netflix_titles_clean
WHERE date_added IS NOT NULL
LIMIT 10;

# Add a column to take the normalized date
ALTER TABLE netflix_titles_clean
ADD COLUMN date_added_clean DATE;

SET SQL_SAFE_UPDATES = 0;

SELECT COUNT(*) 
FROM netflix_titles_clean
WHERE date_added IS NULL OR TRIM(date_added) = '';

# To convert the date string to the date type
UPDATE netflix_titles_clean
SET date_added_clean = STR_TO_DATE(TRIM(date_added), '%M %d, %Y')
WHERE date_added IS NOT NULL
AND TRIM(date_added) != '';

SELECT date_added_clean
FROM netflix_titles_clean
LIMIT 10;

SET SQL_SAFE_UPDATES = 1;

# Convert release_year to integer type
SELECT release_year
FROM netflix_titles_clean
LIMIT 10;

ALTER TABLE netflix_titles_clean
MODIFY COLUMN release_year INT;

# Extract the added year and month form date_added_clean
ALTER TABLE netflix_titles_clean
ADD COLUMN year_added INT,
ADD COLUMN month_added INT;

UPDATE netflix_titles_clean
SET 
    year_added = YEAR(date_added_clean),
    month_added = MONTH(date_added_clean)
WHERE date_added_clean IS NOT NULL;

-- Verify the result of extraction
SELECT year_added, month_added
FROM netflix_titles_clean
LIMIT 10; 

-- Duration normalization
SELECT duration
FROM netflix_titles_clean
LIMIT 10; 

ALTER TABLE netflix_titles_clean
ADD COLUMN duration_int INT, 
ADD COLUMN duration_unit VARCHAR(10); 

SET SQL_SAFE_UPDATES = 0;

UPDATE netflix_titles_clean
SET duration_int = CAST(REGEXP_SUBSTR(duration, '[0-9]+') AS UNSIGNED),
	duration_unit = CASE 
                        WHEN duration LIKE '%min%' THEN 'min'
                        WHEN duration LIKE '%Season%' THEN 'Season'
                    END
WHERE duration IS NOT NULL;

SET SQL_SAFE_UPDATES = 1;

# Check the results of normalization
SELECT duration, duration_int, duration_unit
FROM netflix_titles_clean
LIMIT 10;

-- Handle the missing values
# Quantify the missing values
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN director IS NULL THEN 1 ELSE 0 END) AS director_nulls,
    SUM(CASE WHEN cast IS NULL THEN 1 ELSE 0 END) AS cast_nulls,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS country_nulls,
    SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS rating_nulls,
    SUM(CASE WHEN duration IS NULL THEN 1 ELSE 0 END) AS duration_nulls,
    SUM(CASE WHEN date_added IS NULL THEN 1 ELSE 0 END) AS date_added_nulls,
    SUM(CASE WHEN show_id IS NULL THEN 1 ELSE 0 END) AS show_id_nulls
FROM netflix_titles_clean;

SELECT
    SUM(CASE WHEN TRIM(director) = '' THEN 1 ELSE 0 END) AS director_empty,
    SUM(CASE WHEN TRIM(cast) = '' THEN 1 ELSE 0 END) AS cast_empty,
    SUM(CASE WHEN TRIM(country) = '' THEN 1 ELSE 0 END) AS country_empty,
    SUM(CASE WHEN TRIM(rating) = '' THEN 1 ELSE 0 END) AS rating_empty
FROM netflix_titles_clean;

# Fill empty strings with placeholders
SET SQL_SAFE_UPDATES = 0;

UPDATE netflix_titles_clean
SET director = 'Unknown'
WHERE TRIM(director) = '';

UPDATE netflix_titles_clean
SET cast = 'Not Listed'
WHERE TRIM(cast) = '';

UPDATE netflix_titles_clean
SET country = 'Not Listed'
WHERE TRIM(country) = '';

# Fill empty rating with the mode
UPDATE netflix_titles_clean
SET rating = (
    SELECT rating FROM (
        SELECT rating
        FROM netflix_titles_clean
        WHERE rating IS NOT NULL
        AND TRIM(rating) != ''
        GROUP BY rating
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) AS mode_rating
)
WHERE TRIM(rating) = '' OR rating IS NULL;

SET SQL_SAFE_UPDATES = 1;

-- Genre and Country denormalization
-- Genre denorminalization
# Check the formatting of genre
SELECT listed_in
FROM netflix_titles_clean
LIMIT 10; 

# Create the genre table
DESCRIBE netflix_titles_clean;
ALTER TABLE netflix_titles_clean
ADD PRIMARY KEY (show_id);

CREATE TABLE netflix_genres (
    show_id     VARCHAR(10),
    genre       VARCHAR(100),
    PRIMARY KEY (show_id, genre),
    FOREIGN KEY (show_id) REFERENCES netflix_titles_clean(show_id)
);

# Populate it using recursive CTE
INSERT INTO netflix_genres (show_id, genre)
WITH RECURSIVE genre_split AS (
    # Start with the full listed_in string
    SELECT 
        show_id,
        TRIM(SUBSTRING_INDEX(listed_in, ',', 1)) AS genre,
        IF(
            LOCATE(',', listed_in) > 0,
            TRIM(SUBSTR(listed_in, LOCATE(',', listed_in) + 1)),
            NULL
        ) AS remaining
    FROM netflix_titles_clean
    WHERE listed_in IS NOT NULL
    AND TRIM(listed_in) != ''

    UNION ALL

    # Keep splitting the remaining string using recursion
    SELECT
        show_id,
        TRIM(SUBSTRING_INDEX(remaining, ',', 1)) AS genre,
        IF(
            LOCATE(',', remaining) > 0,
            TRIM(SUBSTR(remaining, LOCATE(',', remaining) + 1)),
            NULL
        ) AS remaining
    FROM genre_split
    WHERE remaining IS NOT NULL
) 
SELECT show_id, genre
FROM genre_split
WHERE genre IS NOT NULL AND TRIM(genre) != '';

# Verify
SELECT COUNT(*) FROM netflix_genres;
SELECT * FROM netflix_genres LIMIT 10; # Results shown in alphabetical order

# Count shows per genre correctly
SELECT genre, COUNT(*) as total
FROM netflix_genres
GROUP BY genre
ORDER BY total DESC;

-- Country denorminalization
# Check the formatting of country
SELECT country
FROM netflix_titles_clean
LIMIT 10; 

# Create the country table
DESCRIBE netflix_titles_clean;

CREATE TABLE netflix_countries (
    show_id     VARCHAR(10),
    country       VARCHAR(100),
    PRIMARY KEY (show_id, country),
    FOREIGN KEY (show_id) REFERENCES netflix_titles_clean(show_id)
);

# Populate it using recursive CTE
INSERT INTO netflix_countries (show_id, country)
WITH RECURSIVE country_split AS (
    # Start with the full country string
    SELECT 
        show_id,
        TRIM(SUBSTRING_INDEX(country, ',', 1)) AS country,
        IF(
            LOCATE(',', country) > 0,
            TRIM(SUBSTR(country, LOCATE(',', country) + 1)),
            NULL
        ) AS remaining
    FROM netflix_titles_clean
    WHERE country IS NOT NULL
    AND TRIM(country) != ''
    AND country != 'Not Listed'

    UNION ALL

    # Keep splitting the remaining string using recursion
    SELECT
        show_id,
        TRIM(SUBSTRING_INDEX(remaining, ',', 1)) AS country,
        IF(
            LOCATE(',', remaining) > 0,
            TRIM(SUBSTR(remaining, LOCATE(',', remaining) + 1)),
            NULL
        ) AS remaining
    FROM country_split
    WHERE remaining IS NOT NULL
) 
SELECT show_id, country
FROM country_split
WHERE country IS NOT NULL AND TRIM(country) != '';

# Count shows per country correctly to verify
SELECT country, COUNT(*) as total
FROM netflix_countries
GROUP BY country
ORDER BY total DESC;



-- EDA
-- Overall Distribution of Data
# What's the split between Movies and TV Shows
SELECT type, 
       COUNT(*) as total,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM netflix_titles_clean
GROUP BY type;
# What's the most common rating
SELECT rating, COUNT(*) AS frequency, 
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM netflix_titles_clean
GROUP BY rating
ORDER BY frequency DESC;
# What genre dominates the catalog
SELECT genre,
       COUNT(*) as frequency,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM netflix_genres
GROUP BY genre
ORDER BY frequency DESC;
# Which countries produce the most contents
SELECT country,
       COUNT(*) as total,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM netflix_countries
GROUP BY country
ORDER BY total DESC;
-- Trends and dynamic of contents
# How has Netflix grown its catalog year by year
SELECT 
    year_added,
    titles_added,
    cumulative_total,
    prev_year_titles,
    ROUND(
        (titles_added - prev_year_titles) * 100.0 / prev_year_titles, 
    2) as yoy_growth_pct
FROM (
    SELECT 
        year_added,
        COUNT(*) as titles_added,
        SUM(COUNT(*)) OVER(ORDER BY year_added) as cumulative_total,
        LAG(COUNT(*)) OVER(ORDER BY year_added) as prev_year_titles
    FROM netflix_titles_clean
    WHERE year_added IS NOT NULL
    AND year_added >= 2015 # Avoid early noise (few samples available during first few years)
    GROUP BY year_added
) yearly_stats
ORDER BY year_added;
# Is Netflix shifting towards more TV shows or Movies recently
SELECT 
    year_added,
    titles_added,
    type,
    cumulative_total,
    prev_year_titles,
    ROUND(
        (titles_added - prev_year_titles) * 100.0 / prev_year_titles, 
    2) as yoy_growth_pct
FROM (
    SELECT 
        year_added,
        type,
        COUNT(*) as titles_added,
        SUM(COUNT(*)) OVER(PARTITION BY type ORDER BY year_added) as cumulative_total,
        LAG(COUNT(*)) OVER(PARTITION BY type ORDER BY year_added) as prev_year_titles
    FROM netflix_titles_clean
    WHERE year_added IS NOT NULL
    AND year_added >= 2015 # Avoid early noise (few samples available during first few years)
    GROUP BY year_added, type
) yearly_stats
ORDER BY type;

# Average movie duration by rating
SELECT rating,
       COUNT(*) as total_movies,
       ROUND(AVG(duration_int), 1) as avg_duration_mins,
       MIN(duration_int) as shortest,
       MAX(duration_int) as longest
FROM netflix_titles_clean
WHERE type = 'Movie'
AND duration_unit = 'min'
AND rating IS NOT NULL
GROUP BY rating
ORDER BY avg_duration_mins DESC;

# Contents duration across different genres
SELECT g.genre,
       n.type,
       ROUND(AVG(n.duration_int), 1) as avg_duration,
       CASE 
           WHEN n.type = 'Movie' THEN 'mins'
           WHEN n.type = 'TV Show' THEN 'seasons'
       END as unit,
       COUNT(*) as total_titles
FROM netflix_genres g
JOIN netflix_titles_clean n ON g.show_id = n.show_id
GROUP BY g.genre, n.type
ORDER BY n.type;

# Do certain countries specialise in certain genres
SELECT country, genre, genre_count
FROM (
    SELECT 
        c.country,
        g.genre,
        COUNT(*) as genre_count,
        ROW_NUMBER() OVER(
            PARTITION BY c.country
            ORDER BY COUNT(*) DESC
        ) as row_num
    FROM netflix_countries c
    JOIN netflix_genres g ON c.show_id = g.show_id
    GROUP BY c.country, g.genre
) ranked
WHERE row_num = 1;

# Which genres are growing fastest in recent years (based on the average percentage growth)?
SELECT
    genre,
    ROUND(AVG(yoy_growth_pct), 2) as avg_yoy_growth_pct
FROM (
    SELECT 
        n.year_added,
        g.genre,
        COUNT(*) as titles_added,
        LAG(COUNT(*)) OVER(PARTITION BY g.genre ORDER BY n.year_added) as prev_year_titles,
        ROUND(
            (COUNT(*) - LAG(COUNT(*)) OVER(PARTITION BY g.genre ORDER BY n.year_added)) 
            * 100.0 / 
            NULLIF(LAG(COUNT(*)) OVER(PARTITION BY g.genre ORDER BY n.year_added), 0)
        , 2) as yoy_growth_pct
    FROM netflix_titles_clean n
    JOIN netflix_genres g ON n.show_id = g.show_id
    WHERE n.year_added IS NOT NULL
    AND n.year_added >= 2015
    GROUP BY n.year_added, g.genre
) yearly_stats
WHERE yoy_growth_pct IS NOT NULL
GROUP BY genre
ORDER BY avg_yoy_growth_pct DESC
LIMIT 20;

-- Export the data files
# Export netflix_titles_clean
SELECT * FROM netflix_titles_clean;

# Export netflix_genres
SELECT * FROM netflix_genres;

# Export netflix_countries
SELECT * FROM netflix_countries;

