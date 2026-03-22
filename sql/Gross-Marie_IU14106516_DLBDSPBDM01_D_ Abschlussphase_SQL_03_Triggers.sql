/* =========================================
TRIGGERS: Business Rule Enforcement

Purpose:
    The following triggers enforce business rules that cannot be
    expressed using standard SQL constraints (CHECK, UNIQUE,
    FOREIGN KEY).

    They run automatically before INSERT or UPDATE operations
    and raise an application-level error if a rule is violated.

Design decision:
    These rules could alternatively be enforced in the
    application layer. Since this project does not implement
    a separate application backend, the logic is implemented
    directly inside the database to guarantee data integrity
    regardless of how the database is accessed.

Execution note:
    All triggers should be created after the base schema and
    seed data have been installed.
========================================= */

USE bookexchange;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_availability_no_overlap_upd
Event: BEFORE UPDATE ON availability
Purpose: Prevents an availability entry from being updated
        to 'active' if another active availability for the
        same copy already exists within an overlapping date
        range.

Rationale:
    A single physical copy cannot be offered in two overlapping
    time windows simultaneously. Otherwise the system could
    promise the same book copy to multiple borrowers.

    Because SQL CHECK constraints cannot reference other rows
    in the same table, a trigger is required to perform this
    cross-row validation.
----------------------------------------- */
CREATE TRIGGER trg_availability_no_overlap_upd
BEFORE UPDATE ON availability
FOR EACH ROW
BEGIN
    IF NEW.status = 'active' THEN
        IF EXISTS (
            SELECT 1
            FROM availability a
            WHERE a.copy_id = NEW.copy_id
              AND a.status = 'active'
              AND a.id <> NEW.id
              AND (
                    NEW.available_from <= a.available_to
                AND NEW.available_to >= a.available_from
              )
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Overlapping active availability for this copy is not allowed (UPDATE).';
        END IF;
    END IF;
END;
//

DELIMITER ;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_availability_no_overlap_ins
Event: BEFORE INSERT ON availability
Purpose: Prevents inserting a new availability entry with
        status = 'active' if it overlaps with an existing
        active availability for the same copy.

Rationale:
    This rule ensures that each physical book copy can only
    be offered in one active availability window at a time.

    A separate trigger is required because MariaDB does not
    support a single trigger covering both INSERT and UPDATE
    events.
----------------------------------------- */
CREATE TRIGGER trg_availability_no_overlap_ins
BEFORE INSERT ON availability
FOR EACH ROW
BEGIN
    IF NEW.status = 'active' THEN
        IF EXISTS (
            SELECT 1
            FROM availability a
            WHERE a.copy_id = NEW.copy_id
              AND a.status = 'active'
              AND (
                    NEW.available_from <= a.available_to
                AND NEW.available_to >= a.available_from
              )
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Overlapping active availability for this copy is not allowed (INSERT).';
        END IF;
    END IF;
END;
//

DELIMITER ;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_loan_block_if_copy_not_available
Event: BEFORE INSERT ON loan
Purpose: Blocks a new loan request if either:
            - the referenced availability entry is not active, or
            - the associated physical book copy is not marked
            as 'available'.

Rationale:
    The loan table references availability, not book_copy
    directly. Therefore the availability status and copy
    status must be checked through a trigger.

    This rule prevents double-booking of the same physical
    book copy and ensures that loans can only be created
    for actively offered copies.
----------------------------------------- */
CREATE TRIGGER trg_loan_block_if_copy_not_available
BEFORE INSERT ON loan
FOR EACH ROW
BEGIN
    DECLARE v_copy_status VARCHAR(20);
    DECLARE v_availability_status VARCHAR(20);

    -- Retrieve the availability status
    SELECT status
    INTO v_availability_status
    FROM availability
    WHERE id = NEW.availability_id;

    -- Reject loan if availability is not active
    IF v_availability_status <> 'active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loan not allowed: availability is not active.';
    END IF;

    -- Retrieve the copy status
    SELECT bc.status
    INTO v_copy_status
    FROM availability a
    JOIN book_copy bc ON bc.id = a.copy_id
    WHERE a.id = NEW.availability_id;

    -- Reject loan if copy is not available
    IF v_copy_status <> 'available' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loan not allowed: copy is not available (status != available).';
    END IF;

END;
//

DELIMITER ;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_loan_no_self_loan
Event: BEFORE INSERT ON loan
Purpose: Prevents a member from borrowing their own book copy.

Rationale:
    In a peer-to-peer book exchange system, lender and borrower
    must always be different members.

    Allowing self-loans would violate the logical model and
    distort statistics such as lending activity and trust scores.
----------------------------------------- */
CREATE TRIGGER trg_loan_no_self_loan
BEFORE INSERT ON loan
FOR EACH ROW
BEGIN
    IF NEW.borrower_id = NEW.lender_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loan not allowed: lender and borrower must be different members.';
    END IF;
END;
//

DELIMITER ;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_loan_no_self_loan_upd
Event: BEFORE UPDATE ON loan
Purpose: Prevents updates that would result in a member lending
         a book to themselves.

Rationale:
    Even if a loan was originally valid, an UPDATE operation
    could change borrower_id or lender_id and violate the
    self-loan restriction. This trigger ensures the rule
    remains enforced after updates.
----------------------------------------- */
CREATE TRIGGER trg_loan_no_self_loan_upd
BEFORE UPDATE ON loan
FOR EACH ROW
BEGIN
    IF NEW.borrower_id = NEW.lender_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loan not allowed: lender and borrower must be different members.';
    END IF;
END;
//

DELIMITER ;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_member_self_service_guard
Event: BEFORE UPDATE ON member
Purpose: Enforces self-service restrictions for regular members.

Rationale:
    Members are allowed to update their own profile information
    but must not modify other user accounts or perform privileged
    status changes.

    This trigger checks:
        - the session variable @current_member_id
        - that only the own account is updated
        - that only allowed status values are used
        - that deleted accounts remain permanently deleted.

    Administrative users are excluded from these checks.
----------------------------------------- */

DROP TRIGGER IF EXISTS trg_member_self_service_guard;
//

CREATE TRIGGER trg_member_self_service_guard
BEFORE UPDATE ON member
FOR EACH ROW
BEGIN
    DECLARE v_user VARCHAR(255);
    SET v_user = USER();

    IF NOT (v_user LIKE 'test_admin@%' OR v_user LIKE 'root@%') THEN

        IF @current_member_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Self-service update blocked: @current_member_id is not set.';
        END IF;

        IF OLD.id <> @current_member_id THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Self-service update blocked: members may only update their own account.';
        END IF;

        IF NEW.status = 'suspended' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Self-service update blocked: status "suspended" is admin-only.';
        END IF;

        IF NEW.status NOT IN ('active', 'inactive', 'deleted') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Self-service update blocked: invalid status value.';
        END IF;

        IF OLD.status = 'deleted' AND NEW.status <> 'deleted' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Self-service update blocked: deleted accounts cannot be reactivated.';
        END IF;

    END IF;
END;
//

DELIMITER ;

DELIMITER //

/* -----------------------------------------
TRIGGER: trg_member_audit_update
Event: BEFORE UPDATE ON member
Purpose: Records administrative modifications to member
         accounts in an audit log.

Rationale:
    Changes to member accounts can affect platform trust,
    permissions and moderation decisions. Therefore all
    administrative updates are logged.

    The audit log stores:
        - affected table
        - action type
        - record id
        - previous values
        - new values
        - database user performing the change
        - timestamp

    Only administrative users are logged to avoid unnecessary
    logging of normal self-service profile updates.
----------------------------------------- */
CREATE TRIGGER trg_member_audit_update
BEFORE UPDATE ON member
FOR EACH ROW
BEGIN
    IF USER() LIKE 'test_admin@%' THEN
        INSERT INTO admin_audit_log(
            table_name, action, record_id,
            old_data, new_data, changed_by
        )
        VALUES (
            'member',
            'UPDATE',
            OLD.id,
            JSON_OBJECT(
                'first_name', OLD.first_name,
                'last_name', OLD.last_name,
                'email_address', OLD.email_address,
                'status', OLD.status,
                'role', OLD.role
            ),
            JSON_OBJECT(
                'first_name', NEW.first_name,
                'last_name', NEW.last_name,
                'email_address', NEW.email_address,
                'status', NEW.status,
                'role', NEW.role
            ),
            USER()
        );
    END IF;
END;
//

DELIMITER ;