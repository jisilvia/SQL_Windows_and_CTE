-- Reconnecting to sakila database via AWS RDS
CREATE DATABASE sakila;
SHOW DATABASES;

-- Setting default database
USE sakila;

-- Verifying restore
SELECT *
FROM actor;

SELECT *
FROM active_customer;


/*
Aggregate Function + Subquery

01 - Return a film's title, length, the average length for 
all films with a subquery, and if the film's length is less 
than the average
*/
SELECT
	title,
	length,
	(
		SELECT AVG(length)
		FROM film
	) AS avg_length_for_all_films,
	length <
	(
		SELECT AVG(length)
		FROM film
	) AS length_less_than_avg_for_all_films
FROM film;

-- AGGREGATE FUNCTIONS

/*
Aggregate Function + Window Function

02 - Return a film's title, length, the average length for 
all films with a window function, and if the film's length 
is less than the average
*/
SELECT
	title,
	length,
	AVG(length) OVER () AS avg_length_for_all_films,						# finds average length for all results (OVER() = all) and alias them
	length < AVG(length) OVER () AS length_less_than_avg_for_all_films		# length is less than average length of all films returned; returns boolean value
FROM film;


/*
Aggregate Function + Window Function + PARTITION BY

03 - Return the film title, length, and the average length per rating
*/
SELECT
	title,
	length,
	rating,
	AVG(length) OVER (
		PARTITION BY rating
	) AS avg_length_per_rating
FROM film;


/*
PARTITION BY Multiple Columns

04 - Return the film title, length, rating, rental_duration, 
and the average length per rating and rental_duration
*/
SELECT
	title,
	length,
	rating,
	AVG(length) OVER (
		PARTITION BY 
			rating,
			rental_duration 
	) AS avg_length_per_rating_rental_duration,				# average length for all film with ex: G rating and rental duration of 3 days; similar to group by but seperate for all results
	rental_duration
FROM film;


-- RANKING FUNCTIONS

/*
ROW_NUMBER() - Number of current row within its partition

05 - Return the row number, title, rating, length for all films sorted by length within a rating partition
	 Window: all rows
*/

# creates row number for ranking
SELECT
	ROW_NUMBER() OVER(
		PARTITION BY rating
		ORDER BY length			# sorts results by length per rating
	) AS row_num,				# row numbers reset based on partition
	title,
	rating,
	length 
FROM film;

/*
06 - Rank G-rated Films Based on Length

ROW_NUMBER() doesn't have duplicates
1,2,3,4,5

RANK() has duplicates and sequence gaps
1,2,2,4,5

DENSE_RANK() has duplicates but NO sequence gaps
1,2,2,3,4

PERCENT_RANK() - row's percentile
- percentage of values < the current row
- values range from 0 to 1 

CUME_DIST() - cumulative distribution
- percentage of values <= to the current row
*/

-- a. ROW_NUMBER()
SELECT
	title,
	length,
	ROW_NUMBER() OVER (
		ORDER BY length 
	) AS length_row_number
FROM film 
WHERE rating = 'G';


-- b. RANK() - Issue: duplicate/skipped ranking if films have the same length
SELECT
	title,
	length,
	ROW_NUMBER() OVER (
		ORDER BY length 
	) AS length_row_number,
	RANK() OVER(
		ORDER BY length 		# order matters!
	) AS length_rank
FROM film 
WHERE rating = 'G';


-- c. DENSE_RANK() - Issue: duplicates, but no sequence gaps
SELECT
	title,
	length,
	ROW_NUMBER() OVER (
		ORDER BY length 
	) AS length_row_number,
	RANK() OVER(
		ORDER BY length 
	) AS length_rank,
	DENSE_RANK() OVER(
		ORDER BY length			# order matters!
	) AS length_dense_rank
FROM film 
WHERE rating = 'G';


-- d. PERCENT_RANK - x% of values are LESS THAN than current row's length
SELECT
	title,
	length,
	ROW_NUMBER() OVER (
		ORDER BY length 
	) AS length_row_number,
	RANK() OVER(
		ORDER BY length 
	) AS length_rank,
	DENSE_RANK() OVER(
		ORDER BY length			
	) AS length_dense_rank,
	PERCENT_RANK() OVER(
		ORDER BY length 
	) AS length_percent_rank
FROM film 
WHERE rating = 'G';


-- e. CUME_DIST - x% of values are LESS THAN or EQUAL TO current row's length
SELECT
	title,
	length,
	ROW_NUMBER() OVER (
		ORDER BY length 
	) AS length_row_number,
	RANK() OVER(
		ORDER BY length 
	) AS length_rank,
	DENSE_RANK() OVER(
		ORDER BY length			
	) AS length_dense_rank,
	PERCENT_RANK() OVER(
		ORDER BY length 
	) AS length_percent_rank,
	CUME_DIST() OVER(
		ORDER BY length 
	) AS length_cume_dist
FROM film 
WHERE rating = 'G';


/*
PARTITION BY + ORDER BY

07 - Return the row number, title, rating, and length for all films
	 Reset the row number when the rating changes (each rating will have its own set of row numbers)
	 Sort results within the window by the film's length
	 Window: by rating
*/
SELECT 
	ROW_NUMBER() OVER(
		PARTITION BY rating		# resets row number when rating changes (group by rating, order by length)
		ORDER BY length
	) AS row_num,
	title,
	rating,
	length 
FROM film;


/*
Filter by window function output with a CTE

08 - Return the title, rating, and length for the films shortest in length per rating

	 1. Create a CTE to hold the ranked results
	 2. Query the CTE based on the rank number
*/
WITH length_ranked_films AS(			# creating CTE
	SELECT 								# selecting main columns
		title,
		rating,
		length,
		RANK() OVER(					# rank & partition
			PARTITION BY rating 
			ORDER BY length
		) AS length_rank
	FROM film
)
SELECT *								# select specific result with filter
FROM length_ranked_films WHERE length_rank =1;



-- VALUE FUNCTIONS

/*
09 - Select a film's title, rating, length, and the following per rating
	 Order matters (value functions)
	 	FIRST_VALUE()
	 	LAST_VALUE()
	 Order does NOT matter (regular aggregate)
		MIN()
		MAX()
 */
SELECT 
	title,
	rating,
	length,
	FIRST_VALUE(length) OVER(		# selects length of longest films for comparison
		PARTITION BY rating 
		ORDER BY length 
	) AS first_film_length,
	LAST_VALUE(length) OVER(		# selects length of shortest films for comparison
		PARTITION BY rating
		ORDER BY length 
		RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING	# last_value = current row by default -> must include frame to include all records
	) AS last_film_length,
	MIN(length) OVER(				# same as last_value
		PARTITION BY rating
	) AS min_film_length
FROM film;


/*
Period-Over-Period Analysis with LAG()

10 - Calculate the month-over-month rental revenue % growth for 2005
	 1. Create GROUP BY to get per month revenue
	 2. Get previous month's revenue with the LAG() window function
	    LAG() accesses a previous row
	 3. Calculate revenue % growth
	    ((current revenue - previous month's revenue) / previous month's revenue) * 100
*/
SELECT 
	LEFT(payment_date, 7) AS payment_month,		# 7 = number of characters; 4 for year, 2 for month, 1 dash
	SUM(amount) AS revenue,
	LAG(SUM(amount), 1) OVER(
		ORDER BY LEFT(payment_date, 7)			# order matters - want to preserve order
	) AS previous_month_revenue,
	(
		(SUM(amount) - LAG(SUM(amount), 1) OVER(ORDER BY LEFT(payment_date, 7)))
		/
		LAG(SUM(amount), 1) OVER(ORDER BY LEFT(payment_date, 7))
	) * 100 AS revenue_growth
FROM payment 
WHERE payment_date BETWEEN '2005-01-01' AND '2005-12-31 23:59:59'
GROUP BY payment_month;


/*
Calculating Running Totals
Running Total = compounded total

11 - Calculate the running revenue total when selecting the payment_id, payment_date, amount for 2005-05-24

	 Order matters when calculating running totals
*/
SELECT
	payment_id,
	payment_date,
	amount,
	SUM(amount) OVER (
		ORDER BY payment_date
	) AS running_total
FROM payment 
WHERE payment_date BETWEEN '2005-05-24' AND '2005-05-24 23:59:59'	# faster than DATE function


/*
Calculating Running Totals for GROUPed Data

12 - Calculate the running revenue total for revenue GROUPed BY the payment date day for 2005
	 Return the day, revenue for the day, and the running total up until the current day in the result
	
	 1. Create a CTE to hold the GROUPed BY payment date day results
	 2. Query the CTE and do a SUM() window function on the revenue to get the running total
	
	 Remember, order matters
*/

# Grouped data -> must add common table expression
WITH rental_revenue_by_day AS (
	SELECT 
		DATE(payment_date) AS payment_date_day,
		SUM(amount) as revenue 
	FROM payment 
	WHERE payment_date BETWEEN '2005-01-01' AND '2005-12-31 23:59:59'
	gROUP BY payment_date_day
	ORDER BY payment_date_day
)
SELECT 
	payment_date_day, 
	revenue,
SUM(revenue) OVER(
	ORDER BY(payment_date_day)
	) AS running_revenue_total
FROM rental_revenue_by_day;


/*
Per Group Ranking

13 - Rank films within their genre based on their rental count
	 Use DENSE_RANK()

	 The rank should reset when moving onto the next genre
*/
SELECT 
	film.title,
	category.name AS genre,
	COUNT(rental.rental_id) AS rental_count,
	DENSE_RANK() OVER(
		PARTITION BY category.name 
		ORDER BY COUNT(rental.rental_id) DESC 
	) AS rental_rank
FROM film
JOIN film_category 
	ON film.film_id = film_category.film_id 
JOIN category
	ON film_category.category_id = category.category_id
JOIN inventory 
	ON film.film_id = inventory.film_id 
JOIN rental 
	ON inventory.inventory_id = rental.inventory_id
GROUP BY film.title; 


/*
Get the Top # Per Group

14 - Get the top 3 rented films per genre

	 1. Create a CTE with the previous query
	 2. Query the CTE and filter based on the rental rank
*/

WITH rentals_ranked AS(
	SELECT 
		film.title,
		category.name AS genre,
		COUNT(rental.rental_id) AS rental_count,
		DENSE_RANK() OVER(
			PARTITION BY category.name 
			ORDER BY COUNT(rental.rental_id) DESC 
		) AS rental_rank
	FROM film
	JOIN film_category 
		ON film.film_id = film_category.film_id 
	JOIN category
		ON film_category.category_id = category.category_id
	JOIN inventory 
		ON film.film_id = inventory.film_id 
	JOIN rental 
		ON inventory.inventory_id = rental.inventory_id
	GROUP BY film.title
)
SELECT *
FROM rentals_ranked
WHERE rental_rank <= 3;
