/* =========================================
ROLE AND PRIVILEGE MODEL
   
Purpose:
    This section implements the authorization model of the
    book exchange application based on the principle of
    least privilege.

    Each role receives only the permissions required for
    its intended responsibilities.

Roles:
    - app_admin:
        Administrative role with full operational access
        to all core tables and read access to analytical
        and audit views.

    - app_member:
        Regular application user role with restricted
        access focused on catalogue browsing, transaction
        handling and self-service profile maintenance.

Design rationale:
    Sensitive personal data should not be exposed through
    unrestricted table access.

    Therefore, privacy-oriented views are used as a
    protection layer for regular members, while direct
    table access is reserved for administrative users
    where necessary.
========================================= */

USE bookexchange;

-- -----------------------------------------
-- SECTION 1: ROLE CREATION
--
-- Purpose:
--     Creates the database roles used by the authorization
--     model of the application.
--
-- Design rationale:
--     Roles simplify privilege management because permissions
--     can be assigned once to a role and then inherited by
--     multiple database users.
-- -----------------------------------------
CREATE ROLE IF NOT EXISTS app_member;
CREATE ROLE IF NOT EXISTS app_admin;

-- -----------------------------------------
-- SECTION 2: ADMIN ROLE
--
-- Purpose:
--     Grants the administrative role full operational access
--     to all core domain tables.
--
-- Scope:
--     Admins may create, read, update and delete data in the
--     operational schema, but they do not receive DDL rights
--     in this model.
--
-- Design rationale:
--     Administrators must be able to correct data, moderate
--     content, manage catalogue entries and inspect platform
--     activity, including analytical and audit information.
-- -----------------------------------------

-- Full DML access to all operational tables
GRANT SELECT, INSERT, UPDATE, DELETE ON language TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON publisher TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON author TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON genre TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON book TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON book_author TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON book_genre TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON book_copy TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON location TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON availability TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON loan TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON rating TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON member TO app_admin;

-- Read access to analytical views and privacy views
GRANT SELECT ON dm_book_performance TO app_admin;
GRANT SELECT ON dm_member_stats TO app_admin;
GRANT SELECT ON vw_report_loans_per_city_month TO app_admin;
GRANT SELECT ON vw_dm_member_dim TO app_admin;
GRANT SELECT ON vw_dm_book_dim TO app_admin;
GRANT SELECT ON vw_dm_loan_fact TO app_admin;
GRANT SELECT ON vw_public_member_profile TO app_admin;
GRANT SELECT ON vw_location_search TO app_admin;

-- Read access to the administrative audit trail
GRANT SELECT ON admin_audit_log TO app_admin;

-- -----------------------------------------
-- SECTION 3: MEMBER ROLE
--
-- Purpose:
--     Grants the regular member role only the permissions
--     required for everyday platform use.
--
-- Functional scope:
--     - browse public catalogue data
--     - manage transactional activities
--     - maintain own profile data
--     - maintain own addresses
--
-- Security goal:
--     Members must not receive unrestricted access to
--     sensitive personal data of other users.
-- -----------------------------------------

-- -----------------------------------------
-- SUBSECTION 3.1: READ ACCESS THROUGH PRIVACY VIEWS
--
-- Purpose:
--     Allows members to see public profile and location
--     information without accessing sensitive base-table data.
-- -----------------------------------------
GRANT SELECT ON vw_public_member_profile TO app_member;
GRANT SELECT ON vw_location_search TO app_member;

-- -----------------------------------------
-- SUBSECTION 3.2: READ-ONLY ACCESS TO CATALOGUE DATA
--
-- Purpose:
--     Allows members to browse books, authors, genres,
--     publishers and related catalogue assignments.
--
-- Design rationale:
--     Catalogue data is non-sensitive and required for
--     searching, filtering and discovering books.
-- -----------------------------------------
GRANT SELECT ON language TO app_member;
GRANT SELECT ON publisher TO app_member;
GRANT SELECT ON author TO app_member;
GRANT SELECT ON genre TO app_member;
GRANT SELECT ON book TO app_member;
GRANT SELECT ON book_author TO app_member;
GRANT SELECT ON book_genre TO app_member;

-- -----------------------------------------
-- SUBSECTION 3.3: TRANSACTIONAL DOMAIN ACCESS
--
-- Purpose:
--     Allows members to participate in the platform's
--     operational workflows such as offering books,
--     managing availabilities, creating loans and
--     submitting ratings.
--
-- Design rationale:
--     Members need write access to transactional tables
--     in order to use the application meaningfully.
--     Row-level business restrictions are enforced by
--     triggers and application logic.
-- -----------------------------------------
GRANT SELECT, INSERT, UPDATE ON book_copy TO app_member;
GRANT SELECT, INSERT, UPDATE ON availability TO app_member;
GRANT SELECT, INSERT, UPDATE ON loan TO app_member;
GRANT SELECT, INSERT, UPDATE ON rating TO app_member;

-- -----------------------------------------
-- SUBSECTION 3.4: ADDRESS MAINTENANCE
--
-- Purpose:
--     Allows members to maintain their own location data.
--
-- Design rationale:
--     Members must be able to store or update addresses
--     for pickup purposes, but should not be able to read
--     all address details of all users directly from the
--     base table.
-- -----------------------------------------
GRANT INSERT, UPDATE ON location TO app_member;
GRANT SELECT (id) ON location TO app_member;

-- -----------------------------------------
-- SUBSECTION 3.5: SELF-SERVICE PROFILE MAINTENANCE
--
-- Purpose:
--     Allows members to update selected columns of their
--     own member account.
--
-- Design rationale:
--     Members require limited self-service capabilities
--     such as changing profile details or contact data.

--     The actual ownership check and status restrictions
--     are enforced by a dedicated trigger.
-- -----------------------------------------

-- Minimal SELECT permission required for WHERE id = ?
GRANT SELECT (id) ON member TO app_member;

-- Restricted UPDATE permission for self-service profile changes
GRANT UPDATE (first_name, last_name, email_address, phone_number,
              profile_picture_url, about_me, password_hash, status)
ON member TO app_member;