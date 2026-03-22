/* =========================================    
BOOK EXCHANGE APP DATABASE
  Database schema for a book exchange platform
  Project Phase 1.2 - Implementation and Reflection Phase
  Course: DLBDSPBDM01_D | Student ID: IU14106516
  Database System: MariaDB (InnoDB Engine)

Purpose:
    Creates the database and all physical base tables required
    for the operational model of the book exchange application.

Execution note:
    This file must be executed before any data population,
    trigger creation, view creation, role grants or test scripts.

    ARCHITECTURE OVERVIEW:
    This schema implements a relational database for a local
    book exchange app. The model follows the Third Normal Form
    (3NF) and separates concerns into:
        - Book metadata (book, author, genre, publisher, language)
        - Physical copies (book_copy)
        - Availability and locations (availability, location)
        - Transactions (loan, rating)
        - Users (member)

    DESIGN DECISIONS:
    1. book vs. book_copy: Separation between a literary work
       (book) and its physical copies (book_copy). A single work
       can be owned by multiple members in different conditions.
       The alternative — one combined table — would have caused
       redundancy in book metadata.

    2. availability as a standalone entity: Allows time-limited
       and location-dependent availability (e.g. "only in July
       at address X"). Alternative: a status flag directly in
       book_copy would be less flexible and less query-friendly.

    3. rating tied to loan (not book_copy): Member behaviour is
       rated, not the book itself. A book-level rating would have
       been an alternative, but member reliability is more relevant
       for a peer-to-peer exchange platform.

    4. RESTRICT instead of CASCADE for core entities: Members and
       books cannot be deleted automatically, preserving historical
       loan and rating data. Only dependent junction tables use CASCADE.

    INDEX STRATEGY OVERVIEW:
    Indexes trade write performance for read performance: every
    INSERT/UPDATE/DELETE must also update all affected indexes.
    The following strategy was applied throughout this schema:

        - Single-column indexes on frequently filtered attributes
          (status fields, city, ISBN) cover the most common WHERE clauses.
        - Composite indexes are used where two columns appear together
          in WHERE or ORDER BY clauses (e.g. available_from + available_to,
          last_name + first_name), because a composite index is more
          efficient than two separate single-column indexes for those queries.
        - Reverse indexes on junction tables (author_id, book_id) allow
          efficient lookups in both directions without scanning the full table.
        - FULLTEXT indexes replace LIKE '%...%' for title search, which
          cannot use a regular B-tree index and would cause full table scans.
        - Foreign key columns are always indexed: MariaDB uses them
          in JOIN operations and referential integrity checks on every
          INSERT and DELETE.
        - Columns with very low cardinality (e.g. status ENUM with 3-4
          values) are still indexed because the query planner can use them
          efficiently when combined with other selective conditions.

    CONSTRAINT vs. INDEX CONVENTION:
    This schema separates integrity rules from performance optimisations
    using explicit syntax:
        - CONSTRAINT ... UNIQUE (...) declares a uniqueness business rule.
          MariaDB automatically creates a backing B-tree index for it,
          but the intent is data integrity, not query speed.
        - INDEX ... (...) declares a pure performance index with no
          integrity meaning. Its sole purpose is to speed up queries.
    Both produce identical internal index structures in InnoDB, but the
    explicit naming makes the intent of each definition immediately clear.
========================================= */

/* =========================================
CREATE DATABASE

UTF8MB4 is chosen over UTF8 because it supports full Unicode, including emojis.
utf8mb4_unicode_ci enables language-aware sorting.
========================================= */
CREATE DATABASE IF NOT EXISTS bookexchange
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Activate database usage
-- All subsequent commands will be executed on this database
USE bookexchange;

/* =========================================
TABLE: member

Entity for registered members of the book exchange app.
Stores all user data including authentication and profile.

Design decisions:
    - password_hash instead of plaintext (security).
    - ENUM for status and role instead of separate lookup tables, since
      the value sets are fixed and small.

INDEX RATIONALE:
    - index_member_status: Many queries filter by status (e.g. "show all
      active members"). Without this index, every such query would scan
      the entire table. Low cardinality (4 values) is acceptable here
      because the WHERE clause is almost always combined with other conditions.
    - uq_member_email (backing index): Email is used on every login attempt.
      This is a high-frequency point lookup (WHERE email_address = ?).
      The UNIQUE constraint enforces integrity (no duplicates) and MariaDB
      automatically creates a backing B-tree index for fast lookups.

STATE MACHINE: MEMBER ACCOUNT
   Allowed states:
       active -> inactive -> active
       active -> suspended -> active
       active -> deleted (terminal state)

   Business rules:
       - deleted accounts cannot be reactivated.
       - suspended accounts cannot borrow or lend.
       - enforced through ENUM(status) and application logic.
========================================= */
CREATE TABLE member (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    email_address VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone_number VARCHAR(30),
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    profile_picture_url VARCHAR(1024),
    about_me  TEXT,
    -- ENUM restricts status to valid states. Prevents free text errors.
    status ENUM('active', 'inactive', 'suspended', 'deleted') NOT NULL DEFAULT 'active',
    role ENUM('member', 'admin') NOT NULL DEFAULT 'member',

    -- Basic validation: email must contain '@' and '.'
    -- Full validation should be handled in the application layer.
    CONSTRAINT chk_member_email CHECK (email_address LIKE '%@%.%'),

    -- Integrity rule: each email address must be unique across all members.
    -- MariaDB automatically creates a backing B-tree index for this constraint,
    -- which also serves the frequent login lookup (WHERE email_address = ?).
    CONSTRAINT uq_member_email UNIQUE (email_address),

    -- Performance index: supports fast filtering by account status
    -- (e.g. "all active members" in admin dashboards and profile lookups).
    INDEX index_member_status (status)

) ENGINE=INNODB COMMENT='Registered members of the book exchange app';


/* =========================================
TABLE: language

Entity for available book languages.
Normalized table for languages to avoid redundancy.

Design decision:
    - Extracted into its own table instead of ENUM in book,
      so new languages can be added without schema changes.

INDEX RATIONALE:
    - uq_language_iso/uq_language_name: Both columns carry UNIQUE constraints.
      MariaDB creates backing B-tree indexes automatically. These indexes already
      serve as lookup indexes (e.g. WHERE iso_code = 'de' or WHERE name = 'English').
      No additional performance indexes are needed on this small lookup table.
========================================= */
CREATE TABLE language (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    iso_code VARCHAR(5) NOT NULL,
    name VARCHAR(80) NOT NULL,

    -- Integrity rule: ISO codes must be unique (e.g. only one 'de' entry).
    -- The backing index also supports fast lookups when linking books to a language
    -- (WHERE iso_code = 'de'). Short fixed-length strings index very efficiently.
    CONSTRAINT uq_language_iso UNIQUE (iso_code),

    -- Integrity rule: language names must be unique.
    -- The backing index supports name-based lookups in dropdown filters and
    -- search forms (WHERE name = 'English'). Avoids a full table scan.
    CONSTRAINT uq_language_name UNIQUE (name)

) ENGINE=InnoDB COMMENT='Available languages for books (ISO 639-1)';


/* =========================================
TABLE: publisher

Entity for book publishers.
Stores information about publishing houses.

Publisher name depends on the book, not on the author
or genre, therefore it is a separate entity.

INDEX RATIONALE:
    - idx_publisher_name: Publishers are looked up by name when users
      search or filter books by publisher. The UNIQUE constraint backing
      index already covers this. No additional index needed.
========================================= */
CREATE TABLE publisher (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(80) NOT NULL,
    headquarter VARCHAR(80), -- Nullable: not always available

    -- Integrity rule: publisher names must be unique.
    -- The backing index supports name-based lookups and publisher filter queries
    -- (WHERE name = 'Suhrkamp Verlag') without a full table scan.
    CONSTRAINT uq_publisher_name UNIQUE (name)

) ENGINE=InnoDB COMMENT='Publishers';


/* =========================================
TABLE: author

Entity for book authors.
Stores information about authors who wrote the books.

Authors are stored separately because book:author is an
n:m relationship (anthologies, co-authors).

INDEX RATIONALE:
    - idx_author_name (last_name, first_name): A composite index on both
      name columns. Alphabetical author lists (ORDER BY last_name, first_name)
      and name searches (WHERE last_name = ?) both benefit from this single
      index. A composite index is more efficient here than two separate indexes
      because the query planner can satisfy both the filter and the sort order
      from one index scan without an additional sorting step.
========================================= */
CREATE TABLE author (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    bio TEXT, -- Nullable: optional

    -- Performance index: composite index covering both name columns.
    -- Supports: WHERE last_name = ? (prefix match)
    --           ORDER BY last_name, first_name (sort without extra pass)
    --           WHERE last_name = ? AND first_name = ? (exact match)
    -- A single composite index is more efficient than two separate
    -- single-column indexes for queries that use both columns together.
    INDEX idx_author_name (last_name, first_name)

) ENGINE=InnoDB COMMENT='Authors of books';


/* =========================================
TABLE: genre

Entity for book genres.
Lookup table for book genres. Like language: extracted
for flexibility. Books can belong to multiple genres (n:m).

INDEX RATIONALE:
    - uq_genre_name: The UNIQUE constraint backing index already supports
      genre name lookups in filter menus (WHERE name = 'Fantasy').
      No additional performance index needed on this small lookup table.
========================================= */
CREATE TABLE genre (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(80) NOT NULL,
    description TEXT,

    -- Integrity rule: genre names must be unique.
    -- The backing index supports genre name lookups in filter menus and
    -- search queries (WHERE name = 'Fantasy') without a full table scan.
    CONSTRAINT uq_genre_name UNIQUE (name)

) ENGINE=InnoDB COMMENT='Book genres';


/* =========================================
TABLE: book

Entity for books. Represents a literary work/edition (metadata).
NOT the physical copy (-> book_copy).

Design decisions:
    - ISBN is nullable since not all books (self-published, old works) have an ISBN.
    - FULLTEXT index on title + subtitle enables powerful full-text search,
      more efficient than LIKE '%...%'.

INDEX RATIONALE:
    - idx_book_title (FULLTEXT): Title search via LIKE '%keyword%' cannot use
      a regular B-tree index and causes a full table scan on every search.
      A FULLTEXT index uses an inverted index structure, making keyword
      searches across title and subtitle vastly faster as the catalogue grows.
    - uq_book_isbn: ISBN must be unique across all books. The UNIQUE constraint
      backing index also supports fast point lookups (WHERE isbn = '...') such
      as barcode scans or book import flows.
    - idx_book_publisher: Required for JOIN operations between book and publisher
      and for filtering books by publisher. InnoDB also uses foreign key indexes
      during DELETE on the referenced publisher row (referential integrity check).
    - idx_book_language: Same rationale as idx_book_publisher. JOIN between book
      and language, plus referential integrity enforcement on language DELETE.
========================================= */
CREATE TABLE book (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    publisher_id BIGINT, -- Nullable: publisher not always known
    language_id BIGINT, -- Nullable: language not always known
    title VARCHAR(255) NOT NULL,
    subtitle VARCHAR(255),
    publication_year YEAR,
    isbn VARCHAR(20), -- Nullable: not every book has an ISBN
    pages INT,
    cover_url VARCHAR(1024),
    description TEXT,

    -- RESTRICT: publisher cannot be deleted while books reference it
    FOREIGN KEY (publisher_id) REFERENCES publisher(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT: language cannot be deleted while books reference it
    FOREIGN KEY (language_id) REFERENCES language(id) ON DELETE RESTRICT ON UPDATE CASCADE,

    -- ISBN is optional (NULL allowed). If present, it must be ISBN-10 or ISBN-13 length.
    CONSTRAINT chk_book_isbn CHECK (isbn IS NULL OR LENGTH(isbn) IN (10, 13)),
    -- Pages is optional (NULL allowed). If present, it must be positive.
    CONSTRAINT chk_book_pages CHECK (pages IS NULL OR pages > 0),

    -- Integrity rule: no two books may share the same ISBN.
    -- The backing index also supports fast ISBN point lookups (barcode scans,
    -- imports).
    CONSTRAINT uq_book_isbn UNIQUE (isbn),

    -- Performance index: replaces LIKE '%keyword%' with an inverted index
    -- structure. Covers both title and subtitle in a single index so that
    -- searches across both columns require only one index scan.
    FULLTEXT INDEX idx_book_title (title, subtitle),

    -- Performance index: required for JOIN book <--> publisher and for the
    -- referential integrity check that runs on every DELETE from publisher.
    INDEX idx_book_publisher (publisher_id),

    -- Performance index: required for JOIN book <--> language and for the
    -- referential integrity check that runs on every DELETE from language.
    INDEX idx_book_language (language_id)

) ENGINE=InnoDB COMMENT='Books (works/editions) - not physical copies';


/* =========================================
TABLE: book_author

Resolves the n:m relationship between book and author.

CASCADE: if a book is deleted, the assignment is removed.

INDEX RATIONALE:
    - uq_book_author (book_id, author_id): Integrity rule preventing an author
      from being linked to the same book more than once. The backing index also
      efficiently covers the lookup "find all authors of book X" (WHERE book_id = ?).
    - idx_book_author_reverse (author_id, book_id): Performance index for the
      reverse direction — "find all books by author Y" (WHERE author_id = ?).
      Without this index, that query would scan the entire junction table.
      Including both columns makes it a covering index: InnoDB resolves the
      query entirely from the index without accessing the main table rows.
========================================= */
CREATE TABLE book_author (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    book_id BIGINT NOT NULL,
    author_id BIGINT NOT NULL,

    FOREIGN KEY (book_id) REFERENCES book(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (author_id) REFERENCES author(id) ON DELETE CASCADE ON UPDATE CASCADE,

    -- Integrity rule: each author can be linked to a book only once.
    -- The backing index also supports "find all authors of book X"
    -- (WHERE book_id = ?) as book_id is the leading column.
    CONSTRAINT uq_book_author UNIQUE (book_id, author_id),

    -- Performance index: covers the reverse direction "find all books by author Y"
    -- (WHERE author_id = ?). Acts as a covering index, InnoDB resolves
    -- the query from this index alone without touching the main table rows.
    INDEX idx_book_author_reverse (author_id, book_id)

) ENGINE=InnoDB COMMENT='Link table books-authors (N:M)';


/* =========================================
TABLE: book_genre

Resolves the n:m relationship between book and genre.
Design identical to book_author for consistency.

INDEX RATIONALE:
    - uq_book_genre (book_id, genre_id): Integrity rule and primary lookup index
      for "find all genres of a given book" (WHERE book_id = ?).
    - idx_book_genre_reverse (genre_id, book_id): Performance index for the reverse
      direction "find all books in a given genre" (WHERE genre_id = ?).
      This is the more frequent query direction (users browse by genre), so the
      reverse index is particularly important for frontend performance.
========================================= */
CREATE TABLE book_genre (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    book_id BIGINT NOT NULL,
    genre_id BIGINT NOT NULL,

    FOREIGN KEY (book_id) REFERENCES book(id)  ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (genre_id) REFERENCES genre(id) ON DELETE CASCADE ON UPDATE CASCADE,

    -- Integrity rule: each genre can be linked to a book only once.
    -- The backing index also supports "find all genres of book X"
    -- (WHERE book_id = ?) as book_id is the leading column.
    CONSTRAINT uq_book_genre UNIQUE (book_id, genre_id),

    -- Performance index: covers the reverse direction "find all books in genre Y"
    -- (WHERE genre_id = ?). This is the primary browsing direction (users filter
    -- by genre) making this index critical for frontend query performance.
    INDEX idx_book_genre_reverse (genre_id, book_id)

) ENGINE=InnoDB COMMENT='Link table books-genres (N:M)';


/* =========================================
TABLE: book_copy

Entity for a physical copy of a book owned by a member.

Design decisions:
    - ENUM for condition_code standardises quality description and simplifies filter queries.
    - status controls whether loan requests are possible.
    - RESTRICT on owner_id: prevents data loss when a member is deleted.

INDEX RATIONALE:
    - idx_copy_book (book_id): Supports "find all physical copies of book X".
      This JOIN is executed on almost every book detail page. Required for the
      referential integrity check on book DELETE.
    - idx_copy_owner (owner_id): Supports "find all copies owned by member Y"
      (user profile, my books). Also required for referential integrity checks.
    - idx_copy_status (status): The availability check (WHERE status = 'available')
      runs on virtually every search query in the system. This is the most
      frequently used filter in the entire schema. Without this index, every
      search would scan the entire book_copy table.
    - idx_copy_condition (condition_code): Supports filtering by condition
      (e.g. "only like_new or new books"). Useful for search refinement and
      analytics on copy quality distribution.
========================================= */
CREATE TABLE book_copy (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    book_id BIGINT NOT NULL,
    owner_id BIGINT NOT NULL,
    -- Standardises condition categories (preferable over free text)
    condition_code ENUM('new', 'like_new', 'very_good', 'good', 'acceptable', 'poor') NOT NULL,
    condition_description TEXT, -- Optional free-text description
    acquisition_date DATE,
    notes TEXT,
    -- Status controls whether loan requests are possible for this copy
    status ENUM('available', 'on_loan', 'unavailable') NOT NULL DEFAULT 'available',

    -- RESTRICT: book master data is preserved even if a copy is deleted
    FOREIGN KEY (book_id) REFERENCES book(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT: ownership history is preserved. Member cannot be deleted while copies exist
    FOREIGN KEY (owner_id) REFERENCES member(id) ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Performance index: supports "find all copies of book X" (JOIN book <--> book_copy).
    -- Also required for the referential integrity check on book DELETE.
    INDEX idx_copy_book (book_id),

    -- Performance index: supports "find all copies owned by member Y" (user profile).
    -- Also required for the referential integrity check on member DELETE.
    INDEX idx_copy_owner (owner_id),

    -- Performance index: the single most critical index in the schema.
    -- WHERE status = 'available' is included in virtually every search query.
    -- Without this index, every search would perform a full table scan
    -- across all book copies.
    INDEX idx_copy_status (status),

    -- Performance index: supports condition-based filtering in search refinement
    -- (e.g. WHERE condition_code IN ('new', 'like_new')).
    -- Also used in analytics to report copy quality distribution.
    INDEX idx_copy_condition (condition_code)

) ENGINE=InnoDB COMMENT='Physical book copies owned by members';


/* =========================================
TABLE: location

Entity for geographic addresses of members (pickup/home addresses).

Design decisions:
    - POINT with SRID 4326 (WGS 84 = GPS standard) enables radius searches ("books near me").
    - CASCADE: if a member is deleted, their addresses are removed too.

INDEX RATIONALE:
    - idx_location_member (member_id): Supports "find all addresses of member X".
      Used when displaying a member's pickup options and during JOIN with
      availability. Required for referential integrity check on member DELETE.
    - idx_location_city (city): City-based filtering is the most common
      non-spatial search pattern (WHERE city = 'Berlin'). Without this index,
      every city search scans the full location table.
    - idx_location_postal_code (postal_code): Supports regional searches as a
      lightweight alternative to full geo-distance calculations. Useful when
      users filter by postcode rather than map radius.
    - idx_location_coordinates (SPATIAL): Required for efficient geo-radius
      queries (e.g. ST_Distance_Sphere or bounding box searches). Without
      a spatial index, every distance-based query would require a full
      table scan and become inefficient as the dataset grows.
========================================= */
CREATE TABLE location (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    member_id BIGINT NOT NULL,
    street VARCHAR(120) NOT NULL,
    house_number VARCHAR(20) NOT NULL,
    postal_code VARCHAR(10) NOT NULL,
    city VARCHAR(120) NOT NULL,
    country_code CHAR(2) DEFAULT 'DE',
    -- POINT stores (longitude, latitude) for spatial queries
    coordinates POINT NOT NULL,
    label ENUM('home', 'work', 'pickup', 'other') NOT NULL DEFAULT 'home',

    -- CASCADE: member deleted -> addresses are removed (no orphaned records)
    FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE ON UPDATE CASCADE,

    -- SRID 4326 = WGS84 GPS standard. Enforces correct coordinate format.
    CONSTRAINT chk_location_srid CHECK (ST_SRID(coordinates) = 4326),

    -- Performance index: supports "find all addresses of member X" and is required
    -- for JOIN availability <--> location and referential integrity on member DELETE.
    INDEX idx_location_member (member_id),

    -- Performance index: supports city-based book searches (WHERE city = 'Berlin').
    -- This is the most common non-spatial filter in the search flow.
    INDEX idx_location_city (city),

    -- Performance index: supports postcode-based regional filtering as a lightweight
    -- alternative to geo-distance calculations (WHERE postal_code = '10115').
    INDEX idx_location_postal_code (postal_code),

    -- Spatial performance index: enables efficient geo-distance and radius
    -- queries on the coordinates column. Required for scalable proximity search.
    SPATIAL INDEX idx_location_coordinates (coordinates)

) ENGINE=InnoDB COMMENT='Addresses and pickup locations for members';


/* =========================================
TABLE: availability

Entity for time periods and conditions under which a book copy can be borrowed.

Design decisions:
    - Standalone entity (instead of a status flag in book_copy), because a
      copy can be available at different locations and during different time windows.

INDEX RATIONALE:
    - idx_availability_copy (copy_id): Supports "find all availability windows
      for copy X". Used in every loan request flow and required for referential
      integrity checks on book_copy DELETE.
    - idx_availability_location (location_id): Supports JOIN availability <--> location.
      Used in the main book search query to filter by city or coordinates.
      Required for referential integrity check on location DELETE.
    - idx_availability_status (status): Filters out paused and archived entries
      early in the query (WHERE status = 'active'). Applied on almost every
      search query alongside idx_copy_status.
    - idx_availability_dates (available_from, available_to): A composite index
      on both date columns. Date-range queries (WHERE available_from <= ? AND
      available_to >= ?) appear in every availability search. A composite index
      is significantly more efficient than two separate single-column indexes
      because the query planner can satisfy both predicates in a single index scan.
========================================= */
CREATE TABLE availability (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    copy_id BIGINT NOT NULL,
    location_id BIGINT NOT NULL,
    available_from DATE NOT NULL,
    available_to DATE NOT NULL,
    -- Default loan duration is 14 days. Configurable per entry.
    max_duration_days SMALLINT DEFAULT 14,
    shipping_possible BOOLEAN NOT NULL DEFAULT false,
    status ENUM('active', 'paused', 'archived') NOT NULL DEFAULT 'active',

    -- CASCADE: book_copy deleted -> availability entry is removed automatically
    FOREIGN KEY (copy_id) REFERENCES book_copy(id) ON DELETE CASCADE  ON UPDATE CASCADE,
    -- RESTRICT: location cannot be deleted while active availabilities reference it
    FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Prevents logically impossible date ranges
    CONSTRAINT chk_availability_dates CHECK (available_from <= available_to),
    -- Minimum loan duration is 1 day
    CONSTRAINT chk_availability_duration CHECK (max_duration_days > 0),

    -- Performance index: supports "find all availability windows for copy X"
    -- and is required for referential integrity checks when a book_copy is deleted.
    INDEX idx_availability_copy (copy_id),

    -- Performance index: supports JOIN availability <--> location used in
    -- city/geo-based searches. Also required for the referential integrity
    -- check on location DELETE.
    INDEX idx_availability_location (location_id),

    -- Performance index: filters out paused/archived entries early in every
    -- search query (WHERE status = 'active'). Applied alongside idx_copy_status.
    INDEX idx_availability_status (status),

    -- Performance index: composite index for date-range filtering
    -- (WHERE available_from <= ? AND available_to >= ?).
    INDEX idx_availability_dates (available_from, available_to)

) ENGINE=InnoDB COMMENT='Availability periods for book copies';


/* =========================================
TABLE: loan

Entity for loan transactions.
The status ENUM drives the entire workflow from request to return.

Design decisions:
    - Separate cancellation_date and cancellation_reason enable analysis of cancellation patterns.
    - RESTRICT on lender_id/borrower_id: loan history is preserved.

INDEX RATIONALE:
    - idx_loan_availability (availability_id): Required for JOIN loan <--> availability
      and for the referential integrity check on availability DELETE/UPDATE.
      Also used to detect whether an availability entry already has an active loan.
    - idx_loan_lender (lender_id): Supports "find all loans where member X is the
      lender" (my lent books view). Required for referential integrity on member DELETE.
    - idx_loan_borrower (borrower_id): Supports "find all loans where member X is
      the borrower" (my borrowed books view). Separate from lender index because
      both directions are queried independently and frequently.
    - idx_loan_status (status): Status filtering (WHERE status = 'active' or
      'overdue') is applied in dashboards, reminder systems, and almost every
      loan list view. Without this index, every such query scans the full loan table.
    - idx_loan_dates (start_date, planned_end_date): Composite index for date-based
      queries (overdue detection, loan timeline views). Covers both columns in one
      index scan, avoiding the need for a separate sort or filter step.

STATE MACHINE: LOAN WORKFLOW
   Valid states:
       requested -> accepted -> active -> returned
                          ↘ cancelled
                          ↘ overdue (if planned_end_date < CURRENT_DATE)

   Business rules:
       - No transition into 'active' without start_date.
       - 'returned' requires actual_end_date.
       - 'cancelled' only allowed before active.
       - Overdue is triggered automatically when end_date passes.

   Enforced by:
       - ENUM(status)
       - CHECK constraints for date consistency
       - Trigger trg_loan_block_if_copy_not_available
       - Trigger trg_loan_no_self_loan (BEFORE INSERT)
       - Trigger trg_loan_no_self_loan_upd (BEFORE UPDATE)
========================================= */
CREATE TABLE loan (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    availability_id BIGINT NOT NULL,
    lender_id BIGINT NOT NULL,
    borrower_id BIGINT NOT NULL,
    request_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    start_date DATE,
    planned_end_date DATE,
    actual_end_date DATE,
    -- Status ENUM models a state machine:
    -- requested -> accepted -> active -> returned
    --           -> cancelled
    --    active -> overdue
    status ENUM('requested', 'accepted', 'active', 'returned', 'cancelled', 'overdue') NOT NULL DEFAULT 'requested',
    cancellation_date DATE,
    cancellation_reason TEXT,

    -- RESTRICT: loan history is preserved even if availability is archived
    FOREIGN KEY (availability_id) REFERENCES availability(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT: member records are retained for transaction history
    FOREIGN KEY (lender_id) REFERENCES member(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (borrower_id) REFERENCES member(id) ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Start date must be before or equal to the planned end date
    CONSTRAINT chk_loan_start_date CHECK (start_date <= planned_end_date OR planned_end_date IS NULL),
    -- Actual return date must not be before the start date
    CONSTRAINT chk_loan_actual_date CHECK (actual_end_date >= start_date OR actual_end_date IS NULL),

    -- Performance index: required for JOIN loan <--> availability and for detecting
    -- whether an availability entry already has an active loan before creating a new one.
    INDEX idx_loan_availability (availability_id),

    -- Performance index: supports "find all loans where member X is the lender".
    -- Also required for referential integrity on member DELETE.
    INDEX idx_loan_lender (lender_id),

    -- Performance index: supports "find all loans where member X is the borrower".
    -- Kept as a separate index from lender because
    -- both directions are queried independently and with equal frequency.
    INDEX idx_loan_borrower (borrower_id),

    -- Performance index: supports status-based filtering in dashboards and reminder
    -- systems (WHERE status = 'active', 'overdue', etc.). Without this index,
    -- every loan list view requires a full table scan.
    INDEX idx_loan_status (status),

    -- Performance index: composite index for date-based queries such as overdue
    -- detection (WHERE start_date <= ? AND planned_end_date < CURDATE()).
    INDEX idx_loan_dates (start_date, planned_end_date)

) ENGINE=InnoDB COMMENT='Loan transactions - full lifecycle from request to return';


/* =========================================
TABLE: rating

Entity for mutual ratings after a completed loan transaction.

Design decisions:
    - rating is tied to a loan (not book_copy), because member behaviour is being rated.
    - UNIQUE (loan_id, rater_id): max. 1 rating per person per loan.
    - RESTRICT: rating member records are preserved.

INDEX RATIONALE:
    - uq_rating (loan_id, rater_id): Integrity rule enforcing the one-rating-per-
      rater-per-loan business rule. The backing index also efficiently supports
      "find all ratings for a given loan" (WHERE loan_id = ?), used on loan detail
      pages and to check whether a user has already submitted a rating.
    - idx_rating_rated (rated_member_id): Performance index supporting "find all
      ratings received by member X" (user reputation profile). This query runs on
      every member profile page view. Without this index, every profile load would
      scan the full rating table.
    - idx_rating_stars (stars): Performance index supporting aggregate statistics
      (COUNT(*) GROUP BY stars for star distribution charts, AVG(stars) for
      average score calculation) and filtering members by minimum rating.

Note:
    - The current schema prevents self-loans at loan level.
    - However, self-ratings are not yet enforced directly in the rating table.
    - This rule should be implemented via BEFORE INSERT/BEFORE UPDATE triggers
    - if ratings must be protected independently from application logic.
========================================= */
CREATE TABLE rating (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    loan_id BIGINT NOT NULL,
    rater_id BIGINT NOT NULL,
    rated_member_id BIGINT NOT NULL,
    stars TINYINT NOT NULL,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- CASCADE: if a loan is deleted, its ratings are removed too
    FOREIGN KEY (loan_id) REFERENCES loan(id) ON DELETE CASCADE ON UPDATE CASCADE,
    -- RESTRICT: rating history is preserved
    FOREIGN KEY (rater_id) REFERENCES member(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (rated_member_id) REFERENCES member(id) ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Star range 1-5 (no 0 value as 0 would imply "no opinion")
    CONSTRAINT chk_rating_stars CHECK (stars BETWEEN 1 AND 5),

    -- Integrity rule: each member may rate a given loan only once.
    -- The backing index also supports "find all ratings for loan X"
    -- (WHERE loan_id = ?) and duplicate-check lookups before INSERT.
    CONSTRAINT uq_rating UNIQUE (loan_id, rater_id),

    -- Performance index: supports "find all ratings received by member X".
    -- This query runs on every member profile page view.
    INDEX idx_rating_rated (rated_member_id),

    -- Performance index: supports aggregate statistics (AVG, COUNT GROUP BY stars)
    -- and filtering members by minimum rating in search results.
    INDEX idx_rating_stars (stars)

) ENGINE=InnoDB COMMENT='Mutual ratings after completed loan transactions';

/* =========================================
TABLE: admin_audit_log
Purpose:
    Records administrative changes to critical tables.
    Stores old values, new values, type of action, timestamp,
    and the admin user who performed the modification.

Notes:
  - JSON columns allow flexible logging without schema changes.
  - Logs only structural/administrative updates (not user actions).
========================================= */
CREATE TABLE admin_audit_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(80) NOT NULL,
    action ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id BIGINT NOT NULL,
    old_data JSON,
    new_data JSON,
    changed_by VARCHAR(255) NOT NULL, -- usually USER()
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB
  COMMENT='Audit trail for administrative changes';
