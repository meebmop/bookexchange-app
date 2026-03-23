/* =========================================
DATA-MART VIEWS
Purpose:
    The following views implement an analytical layer on top
    of the operational schema.

    They encapsulate complex JOIN operations and aggregations
    so that reporting queries remain simple, reusable and
    consistent.

Structure:
    - Dimension views (vw_dm_*)
        One row per entity with descriptive attributes only.
        Used as lookup tables in analytical queries.

    - Fact view (vw_dm_loan_fact)
        One row per transaction with calculated metrics.

    - Aggregate views (dm_*)
        Pre-aggregated KPIs used in dashboards and reports.

    - Report views (vw_report_*)
        Multi-dimensional aggregations typically used for
        time-series reporting and analytics dashboards.

Design rationale:
    Views are used instead of materialized tables because
    the dataset size is relatively small and read performance
    is sufficient with the current indexing strategy.
========================================= */

USE bookexchange;

/* -----------------------------------------
VIEW: dm_book_performance
Grain: one row per book

Purpose:
    Aggregates loan activity and rating information per book.

    The view provides key performance indicators (KPIs)
    that help identify popular or highly-rated titles
    in the platform catalogue.

Use cases:
    - "Top 5 most borrowed books" report
    - Average rating leaderboard
    - Loan duration analysis per title

Design rationale:
    MIN(g.name) is used to select a single representative
    genre when a book belongs to multiple genres.

    This avoids row duplication during aggregation. In a
    more advanced analytical model, multiple genres could
    instead be returned via a separate dimension table
    for example.
----------------------------------------- */
CREATE OR REPLACE VIEW dm_book_performance AS
SELECT
    b.id AS book_id,
    b.title,
    -- Selects one representative genre when multiple genres exist.
    MIN(g.name) AS primary_genre,
    COUNT(DISTINCT l.id) AS total_loans,
    ROUND(AVG(DATEDIFF(l.actual_end_date, l.start_date)), 1) AS avg_loan_duration_days,
    ROUND(AVG(r.stars), 2) AS avg_rating
FROM book b
LEFT JOIN book_genre bg ON b.id = bg.book_id
LEFT JOIN genre g ON bg.genre_id = g.id
LEFT JOIN book_copy bc ON b.id = bc.book_id
LEFT JOIN availability av ON bc.id = av.copy_id
LEFT JOIN loan l ON av.id = l.availability_id
LEFT JOIN rating r ON l.id = r.loan_id
GROUP BY b.id, b.title;


/* -----------------------------------------
VIEW: dm_member_stats
Grain: one row per member

Purpose:
    Aggregates activity and trust-related metrics for each
    platform member.

    The view combines lending activity, borrowing activity
    and received ratings to support reputation analysis.

Use cases:
    - Identifying highly active members
    - Trust score calculation
    - Community health reporting
    - Member leaderboards

Design rationale:
    MIN(loc.city) is used to assign a single representative
    city when a member has multiple stored addresses.

    This simplifies reporting queries while still providing
    a useful geographical reference for analytics.
----------------------------------------- */
CREATE OR REPLACE VIEW dm_member_stats AS
SELECT
    m.id AS member_id,
    -- Representative city when multiple addresses exist
    MIN(loc.city) AS primary_city,
    COUNT(DISTINCT bc.id) AS books_offered,
    COUNT(DISTINCT l_borrowed.id) AS total_borrowed,
    COUNT(DISTINCT r.id) AS ratings_received,
    ROUND(AVG(r.stars), 2) AS trust_score
FROM member m
LEFT JOIN book_copy bc ON m.id = bc.owner_id
LEFT JOIN loan l_borrowed ON m.id = l_borrowed.borrower_id
LEFT JOIN rating r ON m.id = r.rated_member_id
LEFT JOIN location loc ON m.id = loc.member_id
GROUP BY m.id;


/* -----------------------------------------
VIEW: vw_report_loans_per_city_month
Grain: one row per (month, city, genre)

Purpose:
    Provides a time-series reporting view for loan activity
    segmented by city and genre.

    The view enables analysis of regional demand patterns
    and genre popularity trends over time.

Use cases:
    - Monthly loan volume per city
    - Genre popularity analysis
    - Regional activity comparison
    - Dashboard time-series charts

Design rationale:
    The start_date column is truncated to the first day of
    the month using DATE_FORMAT() in order to create
    consistent monthly time buckets for reporting.
----------------------------------------- */
CREATE OR REPLACE VIEW vw_report_loans_per_city_month AS
SELECT
    DATE_FORMAT(l.start_date, '%Y-%m-01') AS month_start,
    loc.city,
    g.name AS genre_name,
    COUNT(*) AS loans_count
FROM loan l
JOIN availability av ON l.availability_id = av.id
JOIN book_copy bc ON av.copy_id = bc.id
JOIN book b ON bc.book_id = b.id
JOIN book_genre bg ON b.id = bg.book_id
JOIN genre g ON bg.genre_id = g.id
JOIN location loc ON av.location_id = loc.id
-- Exclude loans that never started (requested/cancelled)
WHERE l.start_date IS NOT NULL
GROUP BY
    DATE_FORMAT(l.start_date, '%Y-%m-01'),
    loc.city,
    g.name;


/* -----------------------------------------
VIEW: vw_dm_member_dim
Grain: one row per member

Purpose:
    Provides a member dimension table for analytical queries.

    The view contains descriptive member attributes and
    derived values that simplify reporting queries.

Use cases:
    - Cohort analysis by registration year
    - Filtering members by status
    - Role-based reporting
    - Simplified joins in analytical queries

Design rationale:
    The derived column registration_year simplifies
    cohort analysis without requiring repeated function
    calls in reporting queries.
----------------------------------------- */
CREATE OR REPLACE VIEW vw_dm_member_dim AS
SELECT
    m.id AS member_id,
    m.first_name,
    m.last_name,
    m.email_address,
    m.registration_date,
    YEAR(m.registration_date) AS registration_year,
    m.status,
    m.role
FROM member m;


/* -----------------------------------------
VIEW: vw_dm_book_dim
Grain: one row per book

Purpose:
    Provides a book dimension table containing descriptive
    metadata for analytical queries.

    The view pre-joins publisher, language and genre tables
    so that analytical queries do not need to repeat these
    joins.

Use cases:
    - Catalogue composition analysis
    - Genre distribution reporting
    - Language-based book statistics
    - Publisher performance reports

Design rationale:
    MIN(g.name) is used to select a representative genre
    when a book is assigned to multiple genres, avoiding
    row duplication in aggregated reports.
----------------------------------------- */
CREATE OR REPLACE VIEW vw_dm_book_dim AS
SELECT
    b.id AS book_id,
    b.title,
    b.subtitle,
    b.isbn,
    b.publication_year,
    p.name AS publisher_name,
    lang.name AS language_name,
    MIN(g.name) AS primary_genre
FROM book b
LEFT JOIN publisher p ON b.publisher_id = p.id
LEFT JOIN language lang ON b.language_id = lang.id
LEFT JOIN book_genre bg ON b.id = bg.book_id
LEFT JOIN genre g ON bg.genre_id = g.id
GROUP BY b.id, b.title, b.subtitle, b.isbn, b.publication_year, p.name, lang.name;


/* -----------------------------------------
VIEW: vw_dm_loan_fact
Grain: one row per loan

Purpose:
    Central fact table for all loan-related analytical queries.

    The view provides transaction-level information together
    with derived metrics such as loan durations and overdue
    indicators.

Use cases:
    - Average loan duration analysis
    - Overdue rate reporting
    - Lending vs. borrowing activity comparison
    - BI tool integration

Design rationale:
    Derived metrics are calculated directly in the view
    to simplify analytical queries and reduce repeated
    calculations in reporting layers.

    The overdue flag covers three possible scenarios:
        1. Loan explicitly marked as 'overdue'
        2. Book returned after planned end date
        3. Planned end date passed and book not yet returned
----------------------------------------- */
CREATE OR REPLACE VIEW vw_dm_loan_fact AS
SELECT
    l.id AS loan_id,
    l.availability_id,
    a.copy_id,
    bc.book_id,
    l.lender_id,
    l.borrower_id,
    l.request_date,
    l.start_date,
    l.planned_end_date,
    l.actual_end_date,
    l.status,

    CASE
        WHEN l.start_date IS NOT NULL AND l.planned_end_date IS NOT NULL
        THEN DATEDIFF(l.planned_end_date, l.start_date)
        ELSE NULL
    END AS planned_duration_days,

    CASE
        WHEN l.start_date IS NOT NULL AND l.actual_end_date IS NOT NULL
        THEN DATEDIFF(l.actual_end_date, l.start_date)
        ELSE NULL
    END AS actual_duration_days,

    CASE
        WHEN l.status = 'overdue'
          OR (l.actual_end_date IS NOT NULL
              AND l.planned_end_date IS NOT NULL
              AND l.actual_end_date > l.planned_end_date)
          OR (l.actual_end_date IS NULL
              AND l.planned_end_date IS NOT NULL
              AND l.planned_end_date < CURRENT_DATE())
        THEN 1 ELSE 0
    END AS is_overdue

FROM loan l
JOIN availability a ON l.availability_id = a.id
JOIN book_copy bc ON a.copy_id = bc.id;


/* =========================================
PRIVACY VIEWS (DATA PROTECTION LAYER)
Purpose:
    These views expose restricted subsets of sensitive tables
    in order to protect personally identifiable information.

    Instead of granting direct SELECT access to base tables,
    application users access sanitized data through these views.

Design rationale:
    This approach implements a database-level privacy layer
    that supports the principle of least privilege while still
    allowing application functionality such as member search
    and location discovery.
========================================= */

/* -----------------------------------------
VIEW: vw_public_member_profile
Grain: one row per member

Purpose:
    Provides a public-facing member profile view containing
    only non-sensitive profile attributes.

Exposed attributes:
    - member id
    - first name
    - last name
    - profile description
    - account status

Hidden attributes:
    - password hash
    - email address
    - phone number
    - internal role information

Use cases:
    - displaying member profiles
    - borrower/lender discovery
    - community browsing features
----------------------------------------- */
CREATE OR REPLACE VIEW vw_public_member_profile AS
SELECT
    m.id,
    m.first_name,
    m.last_name,
    m.about_me,
    m.status
FROM member m;


/* -----------------------------------------
VIEW: vw_location_search
Grain: one row per location

Purpose:
    Provides a privacy-safe location search view that exposes
    only coarse geographical information required for pickup
    discovery.

Exposed attributes:
    - location id
    - city
    - postal code
    - country code
    - coordinates

Hidden attributes:
    - street
    - house number
    - internal location labels

Use cases:
    - searching pickup locations
    - regional filtering of book offers
    - map-based discovery features
----------------------------------------- */
CREATE OR REPLACE VIEW vw_location_search AS
SELECT
    l.id,
    l.city,
    l.postal_code,
    l.country_code,
    l.coordinates
FROM location l;