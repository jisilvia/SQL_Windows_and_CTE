-- Date and String Functions

-- 01 - # of orders per day
SELECT 
	COUNT(OrderNumber) AS number_of_orders, 
	DATE(OrderDate) AS OrderDateDay
FROM Orders
GROUP BY OrderDateDay;

-- 02 - # of orders per month
SELECT 
	DATE_FORMAT(OrderDate, '%Y-%m') AS OrderDateMonth,
	COUNT(OrderNumber) AS order_count
FROM Orders
GROUP BY OrderDateMonth;

# ALternative for larger queries
SELECT
	LEFT(OrderDate, 7) AS OrderMonth,
	COUNT(OrderNumber) AS OrderCount
FROM Orders
GROUP BY OrderMonth;

-- 03 - # of orders per quarter
SELECT 
	QUARTER(OrderDate) AS OrderQuarter,
	YEAR(OrderDate) AS OrderYear,
	COUNT(OrderNumber) AS OrderCount
FROM Orders
GROUP BY 
	OrderQuarter,
	OrderYear;

-- 04 - # of orders and revenue per day
SELECT 
	COUNT(DISTINCT(Orders.OrderNumber)) AS OrderCount, 
	SUM(QuotedPrice * QuantityOrdered) AS DailyRevenue,
	DATE(OrderDate) as DateOrder
FROM Orders
JOIN Order_Details
	ON Orders.OrderNumber = Order_Details.OrderNumber
GROUP BY DateOrder
ORDER BY DateOrder;


-- Create an Orders2021 table to simulate recent data
-- DROP TABLE Orders2021;

-- Copy the Orders schema to Orders2021
CREATE TABLE Orders2021 LIKE Orders;
	# creates empty table with similar schema

-- Select Jan - Mar 2018 data into Orders2021
INSERT INTO Orders2021
SELECT *
FROM Orders
WHERE OrderDate BETWEEN '2018-01-01' AND '2018-03-31';

SELECT *
FROM Orders2021
LIMIT 10;

-- What would the OrderDate look like if we added 3 years to make the OrderDate year 2021?
SELECT
	OrderDate,
	DATE_ADD(OrderDate, INTERVAL 3 YEAR) # add 3 years to go from 2018 to 2021
FROM Orders2021
LIMIT 10;

-- Update OrderDate to reflect 2021. Always add a WHERE to UPDATE and DELETE.
UPDATE Orders2021
SET OrderDate = DATE_ADD(OrderDate, INTERVAL 3 YEAR)
WHERE OrderDate BETWEEN '2018-01-01' AND '2018-03-31'; # always add WHERE when updating

-- Verify update
SELECT 
	DATE(OrderDate) AS OrderDateDay,
	COUNT(*)
FROM Orders2021
GROUP BY OrderDateDay;


-- 05 - How many orders per day for the past month? Do not include orders from today.
-- Only use DATE functions in the WHERE and do not hard code dates.
SELECT
	DATE(OrderDate) AS OrderDateDay,
	COUNT(*) AS OrderCount
FROM Orders2021
WHERE OrderDate BETWEEN DATE_SUB(CURDATE(), INTERVAL 1 MONTH) AND DATE_SUB(CURDATE(), INTERVAL 1 DAY) # subtracting days and months 
GROUP BY OrderDateDay;

SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY);

-- VIEW

-- 06 - Create a VIEW to hold the results for the order count and revenue per day, category, and product name for all dates
	# views = virtual tables from background query
	# makes complex queries easy to read & faster results 
	# alternative to subqueries, which can be messy
/*
 * 1. Identify tables
 * Orders
 * 	OrderNumber
 * Order_Details
 * 	ProductNumber
 * Products
 *  CategoryID
 * Categories
 * 
 * 2. Identify foreign keys
 * 3. GROUP BY
 * 4, Aggregate
 * Run query agains VIEW
 */

CREATE OR REPLACE VIEW OrdersSummary AS							# add OR REPLACE to update views without dropping them first
	SELECT
		OrderDate,
		Products.ProductNumber,
		ProductName,
		CategoryDescription,
		COUNT(DISTINCT(Orders.OrderNumber)) AS TotalOrders,		# only returns disctinct values. important to exlude nulls as this is a one-to-many relationship
		SUM(QuotedPrice * QuantityOrdered) AS Revenue
	FROM Orders 
	JOIN Order_Details 
		ON Orders.OrderNumber = Order_Details.OrderNumber
	JOIN Products 
		ON Order_Details.ProductNumber = Products.ProductNumber 
	JOIN Categories 
		ON Products.CategoryID = Categories.CategoryID 
	GROUP BY 
		OrderDate,
		ProductNumber;

# Display VIEW
SELECT *
FROM OrdersSummary;


-- 07 - Using the VIEW, return the days and order count where 
-- the order count for products in the bikes category was greater than 2
SELECT
	OrderDate,
	COUNT(*)
FROM OrdersSummary
WHERE 
	TotalOrders > 2
	AND CategoryDescription = 'Bikes'
GROUP BY OrderDate;


-- Common Table Expression (CTE)
	# same as view, but temporary

-- 08 - Using a CTE instead of a VIEW, return the days and order count 
-- where the order count for products in the bikes category was greater than 2
WITH OrdersSummary_CTE AS (
	SELECT
		OrderDate,
		Products.ProductNumber,
		ProductName,
		CategoryDescription,
		COUNT(DISTINCT(Orders.OrderNumber)) AS TotalOrders,		
		SUM(QuotedPrice * QuantityOrdered) AS Revenue
	FROM Orders 
	JOIN Order_Details 
		ON Orders.OrderNumber = Order_Details.OrderNumber
	JOIN Products 
		ON Order_Details.ProductNumber = Products.ProductNumber 
	JOIN Categories 
		ON Products.CategoryID = Categories.CategoryID 
	GROUP BY 
		OrderDate,
		ProductNumber
)
SELECT
	OrderDate,
	COUNT(*)
FROM OrdersSummary_CTE
WHERE 
	TotalOrders > 2
	AND CategoryDescription = 'Bikes'
GROUP BY OrderDate;


-- 09 - What is the average daily revenue?
WITH OrdersSummary_CTE AS (
	SELECT
		OrderDate,
		Products.ProductNumber,
		ProductName,
		CategoryDescription,
		COUNT(DISTINCT(Orders.OrderNumber)) AS TotalOrders,		
		SUM(QuotedPrice * QuantityOrdered) AS Revenue
	FROM Orders 
	JOIN Order_Details 
		ON Orders.OrderNumber = Order_Details.OrderNumber
	JOIN Products 
		ON Order_Details.ProductNumber = Products.ProductNumber 
	JOIN Categories 
		ON Products.CategoryID = Categories.CategoryID 
	GROUP BY 
		OrderDate,
		ProductNumber
)
SELECT 
	DATE(OrderDate) AS DateOrderDate,
	AVG(Revenue) AS AverageRevenue
FROM OrdersSummary_CTE
GROUP BY DateOrderDate;


-- 10 - What is the average revenue per category? 
WITH OrdersSummary_CTE AS (
	SELECT
		OrderDate,
		Products.ProductNumber,
		ProductName,
		CategoryDescription,
		COUNT(DISTINCT(Orders.OrderNumber)) AS TotalOrders,		
		SUM(QuotedPrice * QuantityOrdered) AS Revenue
	FROM Orders 
	JOIN Order_Details 
		ON Orders.OrderNumber = Order_Details.OrderNumber
	JOIN Products 
		ON Order_Details.ProductNumber = Products.ProductNumber 
	JOIN Categories 
		ON Products.CategoryID = Categories.CategoryID 
	GROUP BY 
		OrderDate,
		ProductNumber
)
SELECT 
	CategoryDescription ,
	AVG(Revenue) AS AverageRevenue
FROM OrdersSummary_CTE
GROUP BY CategoryDescription;


-- 11 - Compare revenue for yesterday and the day before for bikes and car racks.
-- Indicate if revenue decreased. 
/*
 * Orders2021
 * 1. Tables
 * 2. Foreign keys
 * 3. How to calculate yesterday and the day before
 * 4. Create CTE
 * 5. JOIN CTE with itself to get 2 days ago and yesterday's data on the same row
 */

-- Two days ago and yesterday's dates
SELECT DATE_SUB(CURDATE(), INTERVAL 2 DAY) AS TwoDaysAgo, DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS Yesterday;

-- CTE Comparison
WITH OrdersSummary_CTE AS (
	SELECT
		OrderDate,
		Products.ProductNumber,
		ProductName,
		CategoryDescription,
		COUNT(DISTINCT(Orders2021.OrderNumber)) AS TotalOrders,		
		SUM(QuotedPrice * QuantityOrdered) AS Revenue
	FROM Orders2021 
	JOIN Order_Details 
		ON Orders2021.OrderNumber = Order_Details.OrderNumber
	JOIN Products 
		ON Order_Details.ProductNumber = Products.ProductNumber 
	JOIN Categories 
		ON Products.CategoryID = Categories.CategoryID 
	WHERE OrderDate BETWEEN DATE_SUB(CURDATE(), INTERVAL 2 DAY) AND DATE_SUB(CURDATE(), INTERVAL 1 DAY)
	GROUP BY 
		OrderDate,
		#ProductNumber,
		CategoryDescription 				# group by category to avoid duplicate records
)
SELECT 										# join CTE With itself to compare 2 days ago and yesterday revenue
	YesterdayCTE.OrderDate AS YesterdayOrderDate,
	YesterdayCTE.Revenue AS YesterdayRevenue,
	TwoDaysAgoCTE.OrderDate AS TwoDaysAgoOrderDate,
	TwoDaysAgoCTE.Revenue AS TwoDaysAgoRevenue,
	YesterdayCTE.CategoryDescription
FROM OrdersSummary_CTE YesterdayCTE			# creating two aliases for the same CTE in order to join them
JOIN OrdersSummary_CTE TwoDaysAgoCTE
	ON YesterdayCTE.CategoryDescription = TwoDaysAgoCTE.CategoryDescription
WHERE YesterdayCTE.CategoryDescription IN ('Bikes', 'Car racks')
	AND YesterdayCTE.OrderDate = TwoDaysAgoCTE.OrderDate + 1		# same order date
;
		
## compare dates in same data set -> self join 


