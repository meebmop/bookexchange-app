/* =========================================
TEST SCENARIOS

Purpose:
    The following statements validate the correctness of the
    implemented schema, constraints, triggers and privilege model.

    The test section is divided into:
        - positive end-to-end validation
        - negative integrity and edge-case validation
        - manual role and privilege validation
        - audit trail validation

Execution note:
    Some statements in this section are intentionally designed
    to fail in order to verify business rules and integrity
    enforcement.

    Therefore, this section should be executed manually and
    step by step, especially in SQL clients that stop execution
    after the first error.
========================================= */

USE bookexchange;

/* =========================================
TEST SCENARIO 1: Happy Path

Flow: Search -> Request -> Accept -> Return -> Rate

Actors:
    - Member A (id = 1, Anna): lender, offers copy_id = 1 via availability_id = 1
    - Member B (id = 2, Ben): borrower

Purpose:
    Validates the complete loan lifecycle end-to-end across all
    core tables (book, book_copy, availability, location, loan, rating).
    Confirms that JOINs across six tables return correct results and
    that all status transitions execute without constraint violations.
   ========================================= */

START TRANSACTION;

-- Step 1: Search for all available books in Berlin.
-- Joins six tables to retrieve book metadata, author, genre,
-- copy status, availability window, and pickup location in one query.
-- Filters: city = 'Berlin', copy must be available, availability must be active.
SELECT
    b.id AS book_id,
    b.title,
    a.last_name AS author_last_name,
    g.name AS genre,
    l.city,
    av.id AS availability_id,
    av.max_duration_days
FROM book b
JOIN book_author ba ON b.id = ba.book_id
JOIN author a ON ba.author_id = a.id
JOIN book_genre bg ON b.id = bg.book_id
JOIN genre g ON bg.genre_id = g.id
JOIN book_copy bc ON b.id = bc.book_id
JOIN availability av ON bc.id = av.copy_id
JOIN location l ON av.location_id = l.id
WHERE l.city = 'Berlin' AND bc.status = 'available' AND av.status = 'active';

-- Assumptions for the following steps, based on the search result above:
--   Selected book: "Der Prozess" (book_id = 1)
--   Physical copy: book_copy.id = 1
--   Availability entry: availability.id = 1
--   Lender: member.id = 1 (Anna)
--   Borrower: member.id = 2 (Ben)

-- Step 2: Ensure the technical preconditions for the trigger-based loan insert.
-- The loan trigger requires:
--   - availability.status = 'active'
--   - book_copy.status = 'available'
UPDATE availability
SET status = 'active'
WHERE id = 1;

UPDATE book_copy
SET status = 'available'
WHERE id = 1;

-- Step 3: Ben submits a loan request.
-- Creates a loan record with status = 'requested'.
-- The loan is not yet confirmed by the lender at this point.
INSERT INTO loan (availability_id, lender_id, borrower_id, status)
VALUES (1, 1, 2, 'requested');

-- Capture the auto-generated loan ID for use in subsequent steps.
SET @loan_id := LAST_INSERT_ID();

-- Step 4: Anna accepts the request and the loan becomes active.
-- Sets start_date to today and calculates planned_end_date as 14 days from now.
UPDATE loan
SET status = 'active',
    start_date = CURRENT_DATE,
    planned_end_date = DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY)
WHERE id = @loan_id;

-- Mark the physical copy as on loan.
-- Prevents a second parallel loan request for the same copy.
UPDATE book_copy
SET status = 'on_loan'
WHERE id = 1;

-- Step 5: Ben returns the book. The loan is closed.
-- Sets actual_end_date to today.
UPDATE loan
SET status = 'returned',
    actual_end_date = CURRENT_DATE
WHERE id = @loan_id;

-- Mark the physical copy as available again so it can be borrowed by other members.
UPDATE book_copy
SET status = 'available'
WHERE id = 1;

-- Step 6: Both members rate each other after the completed loan.
-- Each rating references the same loan_id and is constrained to one
-- rating per rater per loan by the UNIQUE constraint uq_rating (loan_id, rater_id).

-- Anna (lender, id = 1) rates Ben (borrower, id = 2).
INSERT INTO rating (loan_id, rater_id, rated_member_id, stars, comment)
VALUES (@loan_id, 1, 2, 5, 'Very reliable borrower, book came back in top condition!');

-- Ben (borrower, id = 2) rates Anna (lender, id = 1).
INSERT INTO rating (loan_id, rater_id, rated_member_id, stars, comment)
VALUES (@loan_id, 2, 1, 5, 'Super straightforward handover, thank you!');

ROLLBACK;


/* =========================================
TEST SCENARIO 2: Data Integrity Validation

Purpose:
    Verifies that CHECK and UNIQUE constraints prevent invalid
    or duplicate data from entering the database.

Method:
    The following INSERT statements are intentionally invalid.
    They must fail and must not leave partial or inconsistent
    data behind.
========================================= */

START TRANSACTION;

-- Step 1: Show the current ratings for loan_id = 1.
-- This result serves as the baseline for comparison.
SELECT
    r.id,
    r.loan_id,
    r.rater_id,
    r.rated_member_id,
    r.stars,
    r.comment,
    r.created_at
FROM rating r
WHERE r.loan_id = 1;

-- Step 2: Attempt to insert a rating with an invalid number of stars.
-- Expected result:
--   ERROR 4025 because chk_rating_stars requires stars BETWEEN 1 AND 5.
SAVEPOINT sp_invalid_stars;
INSERT INTO rating (loan_id, rater_id, rated_member_id, stars, comment)
VALUES (1, 1, 2, 6, 'Test: invalid stars (should fail)');
ROLLBACK TO sp_invalid_stars;

-- Step 3: Attempt to insert a duplicate rating by the same rater
-- for the same loan.
-- Expected result:
--   ERROR 1062 because uq_rating requires (loan_id, rater_id) to be unique.
SAVEPOINT sp_duplicate_rating;
INSERT INTO rating (loan_id, rater_id, rated_member_id, stars, comment)
VALUES (1, 1, 2, 5, 'Test: duplicate rating (should fail)');
ROLLBACK TO sp_duplicate_rating;

-- Step 4: Verify that the number of ratings for loan_id = 1
-- is unchanged after the failed INSERT statements.
SELECT COUNT(*) AS rating_count_after
FROM rating
WHERE loan_id = 1;

ROLLBACK;


/* =========================================
TEST SCENARIO 3: Edge Cases and Constraint Validation

Purpose:
    Verifies that constraints, foreign keys and triggers
    correctly reject invalid operations.

Method:
    Each statement below intentionally violates a rule
    and should therefore fail with the documented error.
========================================= */

START TRANSACTION;

-- Test 3.1: Overlapping active availability for the same copy.
-- Existing active availability:
--   copy_id = 1, availability.id = 1
-- The new row overlaps with that time window.
-- Expected result:
--   ERROR 1644 (45000) from trg_availability_no_overlap_ins.
SAVEPOINT sp_overlap_availability;
INSERT INTO availability (copy_id, location_id, available_from, available_to, max_duration_days, shipping_possible, status)
VALUES (1, 1, '2026-01-01', '2026-12-31', 14, FALSE, 'active');
ROLLBACK TO sp_overlap_availability;

-- Test 3.2: Invalid max_duration_days value.
-- Business rule:
--   max_duration_days must be greater than 0.
-- Expected result:
--   ERROR 4025 from chk_availability_duration.
SAVEPOINT sp_invalid_duration;
INSERT INTO availability (copy_id, location_id, available_from, available_to, max_duration_days)
VALUES (2, 2, '2026-01-01', '2026-02-01', 0);
ROLLBACK TO sp_invalid_duration;

-- Test 3.3: Invalid date range in availability.
-- Business rule:
--   available_from must be less than or equal to available_to.
-- Expected result:
--   ERROR 4025 from chk_availability_dates.
SAVEPOINT sp_invalid_availability_dates;
INSERT INTO availability (copy_id, location_id, available_from, available_to)
VALUES (2, 2, '2026-02-01', '2026-01-01');
ROLLBACK TO sp_invalid_availability_dates;

-- Test 3.4: Invalid email address format.
-- Business rule:
--   email_address must satisfy LIKE '%@%.%'.
-- Expected result:
--   ERROR 4025 from chk_member_email.
SAVEPOINT sp_invalid_email;
INSERT INTO member (first_name, last_name, email_address, password_hash)
VALUES ('Test', 'User', 'falsche-email@com', 'hash');
ROLLBACK TO sp_invalid_email;

-- Test 3.5: Invalid ISBN length.
-- Business rule:
--   ISBN must have length 10 or 13 if present.
-- Expected result:
--   ERROR 4025 from chk_book_isbn.
SAVEPOINT sp_invalid_isbn;
INSERT INTO book (title, isbn)
VALUES ('Invalid Book', '12345');
ROLLBACK TO sp_invalid_isbn;

-- Test 3.6: Loan request for a copy that is already on loan.
-- Step 1:
--   Simulate that copy_id = 1 is already unavailable.
UPDATE book_copy SET status = 'on_loan' WHERE id = 1;

-- Step 2:
--   Attempt to create a new request for the same copy.
-- Expected result:
--   ERROR 1644 (45000) from trg_loan_block_if_copy_not_available.
SAVEPOINT sp_copy_not_available;
INSERT INTO loan (availability_id, lender_id, borrower_id, status)
VALUES (1, 1, 3, 'requested');
ROLLBACK TO sp_copy_not_available;

-- Test 3.7: Attempt to delete a referenced publisher.
-- publisher.id = 1 is still referenced by existing books.
-- Expected result:
--   ERROR 1451 due to ON DELETE RESTRICT on book.publisher_id.
SAVEPOINT sp_delete_publisher;
DELETE FROM publisher
WHERE id = 1;
ROLLBACK TO sp_delete_publisher;

-- Test 3.8: Attempt to delete a member who still owns book copies.
-- member.id = 1 is still referenced by book_copy.owner_id.
-- Expected result:
--   ERROR 1451 due to ON DELETE RESTRICT on book_copy.owner_id.
SAVEPOINT sp_delete_member;
DELETE FROM member
WHERE id = 1;
ROLLBACK TO sp_delete_member;

-- Test 3.9: Invalid spatial reference system.
-- Business rule:
--   Coordinates must use SRID 4326 (WGS84).
-- Expected result:
--   ERROR 4025 from chk_location_srid.
SAVEPOINT sp_invalid_srid;
INSERT INTO location (member_id, street, house_number, postal_code, city, country_code, coordinates, label)
VALUES (1, 'Teststraße', '1', '99999', 'Teststadt', 'DE',
        ST_PointFromText('POINT(13.0000 52.0000)', 3857),
        'home');
ROLLBACK TO sp_invalid_srid;

ROLLBACK;


/* =========================================
ROLE TESTS (MANUAL EXECUTION)

Purpose:
    Validates the least-privilege model for both application
    roles and verifies that role-based restrictions are
    actually enforced at runtime.

Execution note:
    These tests must be executed manually in separate
    database sessions with the respective test users.
========================================= */

-- -----------------------------------------
-- TEST 1: OPTIONAL TEST USER CREATION
--
-- Purpose:
--     Creates dedicated database users for role validation.
--
-- Execution note:
--     Execute these statements once as root/DBA before the
--     role tests below.
--
-- Design note:
--     '%' is used as host wildcard to avoid localhost /
--     127.0.0.1 mismatches in GUI tools.
-- -----------------------------------------

START TRANSACTION;

CREATE USER IF NOT EXISTS 'test_member'@'%' IDENTIFIED BY 'Test123!';
-- Expected result:
--   User 'test_member' is created successfully.

GRANT app_member TO 'test_member'@'%';
-- Expected result:
--   Role app_member is assigned successfully.

SET DEFAULT ROLE app_member FOR 'test_member'@'%';
-- Expected result:
--   app_member becomes the default active role for this user.

CREATE USER IF NOT EXISTS 'test_admin'@'%' IDENTIFIED BY 'Test123!';
-- Expected result:
--   User 'test_admin' is created successfully.

GRANT app_admin TO 'test_admin'@'%';
-- Expected result:
--   Role app_admin is assigned successfully.

SET DEFAULT ROLE app_admin FOR 'test_admin'@'%';
-- Expected result:
--   app_admin becomes the default active role for this user.

COMMIT;


-- -----------------------------------------
-- TEST GROUP 2: ROLE VALIDATION FOR app_member
--
-- Purpose:
--     Confirms that regular members receive only the intended
--     restricted permissions.
-- -----------------------------------------

-- Run the following statements as database user: test_member

START TRANSACTION;

-- Test 2.1: Access to privacy views
-- Expected result:
--   Both SELECT statements succeed.
SELECT * FROM vw_public_member_profile LIMIT 5;
SELECT * FROM vw_location_search  LIMIT 5;

-- Test 2.2: Read access to catalogue data
-- Expected result:
--   Query succeeds.
SELECT id, title, isbn FROM book ORDER BY id LIMIT 5;

-- Test 2.3: Forbidden access to sensitive base-table data
-- Expected result:
--   ERROR 1142/1143 because direct SELECT access is denied.
SAVEPOINT sp_member_forbidden_member_select;
SELECT id, email_address, password_hash FROM member LIMIT 5;
ROLLBACK TO sp_member_forbidden_member_select;

SAVEPOINT sp_member_forbidden_location_select;
SELECT street, house_number, label FROM location LIMIT 5;
ROLLBACK TO sp_member_forbidden_location_select;

-- Test 2.4: Forbidden access to analytical views
-- Expected result:
--   ERROR 1143 because analytical views are admin-only.
SAVEPOINT sp_member_forbidden_dm_view;
SELECT * FROM vw_dm_book_dim LIMIT 5;
ROLLBACK TO sp_member_forbidden_dm_view;

ROLLBACK;

-- -----------------------------------------
-- TEST 3: SELF-SERVICE UPDATE VALIDATION FOR app_member
--
-- Purpose:
--     Confirms that self-service account maintenance is possible
--     only within the intended limits enforced by privileges
--     and triggers.
-- -----------------------------------------

-- Run the following statements as database user: test_member

START TRANSACTION;

-- IMPORTANT:
-- The session variable @current_member_id must be set before
-- executing self-service update statements.
--
-- Example:
--   If test_member corresponds to member.id = 2:
SET @current_member_id = 2;

-- Test 3.1: Allowed update of own profile fields
-- Expected result:
--   UPDATE succeeds.
UPDATE member
SET email_address = 'bennew@example.com',
    about_me = 'Updated by app_member'
WHERE id = 2;

-- Test 3.2: Allowed self-deactivation/self-deletion
-- Expected result:
--   UPDATE succeeds.
UPDATE member SET status = 'inactive' WHERE id = 2;

-- Test 3.3: Forbidden status escalation to suspended
-- Expected result:
--   ERROR 1644 (45000) from trg_member_self_service_guard.
SAVEPOINT sp_member_forbidden_suspend;
UPDATE member SET status = 'suspended' WHERE id = 2;
ROLLBACK TO sp_member_forbidden_suspend;

-- Test 3.4: Forbidden update of another member account
-- Expected result:
--   ERROR 1644 (45000) from trg_member_self_service_guard.
SAVEPOINT sp_member_forbidden_other_account;
UPDATE member SET email_address = 'hijack@example.com' WHERE id = 3;
ROLLBACK TO sp_member_forbidden_other_account;

ROLLBACK;


-- -----------------------------------------
-- TEST 4: ROLE VALIDATION FOR app_admin
--
-- Purpose:
--     Confirms that administrative users have the broader
--     read and write permissions required for management tasks.
-- -----------------------------------------

-- Run the following statements as database user: test_admin

START TRANSACTION;

-- Test 4.1: Direct access to sensitive member data
-- Expected result:
--   Query succeeds.
SELECT id, first_name, last_name, email_address, role
FROM member
LIMIT 5;

-- Test 4.2: Access to privacy and analytical views
-- Expected result:
--   All SELECT statements succeed.
SELECT * FROM vw_public_member_profile LIMIT 5;
SELECT * FROM vw_location_search LIMIT 5;
SELECT * FROM vw_dm_book_dim LIMIT 5;

-- Test 4.3: Administrative write access to catalogue tables
-- Expected result:
--   INSERT and DELETE both succeed.
INSERT INTO genre (name, description)
VALUES ('Test-Genre-Admin', 'Temporary admin test entry');
DELETE FROM genre WHERE name = 'Test-Genre-Admin';

ROLLBACK;


/* =========================================
   AUDIT TRAIL VALIDATION

   Purpose:
       Verifies that administrative updates on the member table
       create an audit entry in admin_audit_log.

   Execution note:
       This test should be executed as test_admin because the
       audit trigger only logs administrative changes.
========================================= */

START TRANSACTION;

-- Step 1: Execute an UPDATE on the member table.
-- Expected result:
--   The update succeeds and creates one new audit entry.
UPDATE member SET status = 'inactive' WHERE id = 1;

-- Step 2: Inspect the most recent audit log entry.
-- Expected result:
--   The latest row shows:
--     - table_name = 'member'
--     - action = 'UPDATE'
--     - record_id = 1
--     - populated old_data and new_data values
SELECT * FROM admin_audit_log
ORDER BY id DESC LIMIT 1;

ROLLBACK;