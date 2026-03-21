/* =========================================
SEED DATA

Purpose:
    Populates all base tables with deterministic sample data
    for demonstration, validation and reporting purposes.

Execution note:
    This file assumes that the schema has already been created.
    It should be executed before triggers, views and test cases.
========================================= */

USE bookexchange;

/* =========================================
DATA POPULATION: CREATING 10 ENTRIES PER TABLE

NOTE: This script assumes that AUTO_INCREMENT values 
start at 1 and count sequentially (1, 2, ..., 10).
Foreign keys (FKs) reference these assumed IDs.
========================================= */

-- Populates the language table with 10 different languages
INSERT INTO language (iso_code, name) VALUES
('de', 'Deutsch'),
('en', 'English'),
('fr', 'Français'),
('es', 'Español'),
('it', 'Italiano'),
('pt', 'Português'),
('nl', 'Nederlands'),
('pl', 'Polski'),
('tr', 'Türkçe'),
('ja', '日本語');

-- Populates the publisher table with 10 publishing houses
INSERT INTO publisher (name, headquarter) VALUES
('Suhrkamp Verlag', 'Berlin'),
('Penguin Random House', 'New York'),
('Hanser Verlag', NULL),
('Rowohlt Verlag', 'Hamburg'),
('Gallimard', 'Paris'),
('Fischer Verlag', 'Frankfurt am Main'),
('HarperCollins', 'New York'),
('Kiepenheuer & Witsch', NULL),
('Diogenes Verlag', 'Zürich'),
('C.H. Beck', 'München');

-- Populates the author table with 10 authors
INSERT INTO author (first_name, last_name, bio) VALUES
('Franz', 'Kafka', 'Bedeutender deutschsprachiger Schriftsteller des 20. Jahrhunderts.'),
('Haruki', 'Murakami', 'Japanischer Autor von Romanen und Kurzgeschichten, bekannt für surrealistische Werke.'),
('Margaret', 'Atwood', 'Kanadische Dichterin, Romanautorin und Essayistin.'),
('Carlos', 'Ruiz Zafón', NULL),
('Elena', 'Ferrante', NULL),
('Michel', 'Houellebecq', NULL),
('J.K.', 'Rowling', 'Britische Schriftstellerin, Autorin der Harry-Potter-Serie.'),
('George', 'Orwell', 'Englischer Schriftsteller, Essayist und Journalist, bekannt für "1984".'),
('Yuval Noah', 'Harari', NULL),
('Juli', 'Zeh', NULL);

-- Populates the genre table with 10 genres
INSERT INTO genre (name, description) VALUES
('Roman', 'Epische Großform der Literatur.'),
('Science-Fiction', 'Literatur, die sich mit fiktiven zukünftigen Entwicklungen befasst.'),
('Krimi', NULL),
('Fantasy', 'Genre der Phantastik mit magischen oder übernatürlichen Elementen.'),
('Sachbuch', 'Vermittelt Fakten und reales Wissen zu einem bestimmten Thema.'),
('Biografie', NULL),
('Dystopie', 'Erzählung, die in einer düsteren, unerwünschten Zukunft spielt.'),
('Thriller', 'Erzeugt Spannung und Nervenkitzel, oft mit einer drohenden Gefahr.'),
('Historischer Roman', 'Roman, dessen Handlung in einer vergangenen Epoche spielt.'),
('Gegenwartsliteratur', NULL);

-- Populates the member table with 10 test users
-- Assumption: IDs will be 1-10
INSERT INTO member (first_name, last_name, email_address, password_hash, phone_number, profile_picture_url, about_me, status, role) VALUES
('Anna', 'Müller', 'anna.mueller@example.com', '$2a$12$KIXxP9H7wZ8vN2qL5RtMveP7Q8wH3N9xYzE4kF6mR7sT8uV9wX0yK', '+49 176 12345678', 'https://example.com/profiles/anna_m.jpg', 'Passionate reader of classic literature and philosophy. Always looking for book recommendations!', 'active', 'member'),
('Ben', 'Schmidt', 'ben.schmidt@example.com', '$2a$12$LJYyQ0I8xA9wO3rM6StNwfQ8R9xI4O0zAF5lG7nS8tU9vW0xY1zL', NULL, 'https://example.com/profiles/ben_s.jpg', 'Science fiction enthusiast. Love trading sci-fi and fantasy books.', 'active', 'member'),
('Carla', 'Schneider', 'carla.schneider@example.com', '$2a$12$MKZzR1J9yB0xP4sN7TuOxgR9S0yJ5P1aB6mH8oT9uV0wX1yZ2aM', '+49 151 98765432', 'https://example.com/profiles/carla_sch.jpg', 'Platform administrator. Here to help with any issues!', 'active', 'admin'),
('David', 'Fischer', 'david.fischer@example.com', '$2a$12$NLAaS2K0zC1yQ5tO8UvPyhS0T1zK6Q2bC7nI9pU0vW1xY2zA3bN', '+49 160 11223344', NULL, 'Looking for Spanish and Latin American literature. Open to shipping books!', 'active', 'member'),
('Eva', 'Weber', 'eva.weber@example.com', '$2a$12$OMBbT3L1aD2zR6uP9VwQziT1U2aL7R3cD8oJ0qV1wX2yZ3aB4cO', NULL, NULL, 'Taking a break from reading. Will be back soon!', 'inactive', 'member'),
('Felix', 'Meyer', 'felix.meyer@example.com', '$2a$12$PNCcU4M2bE3aS7vQ0WxRajU2V3bM8S4dE9pK1rW2xY3zA4bC5dP', '+49 171 55667788', 'https://example.com/profiles/felix_m.jpg', NULL, 'active', 'member'),
('Greta', 'Wagner', 'greta.wagner@example.com', '$2a$12$QODdV5N3cF4bT8wR1XySbkV3W4cN9T5eF0qL2sX3yZ4aB5cD6eQ', '+49 173 44332211', NULL, NULL, 'active', 'member'),
('Hans', 'Becker', 'hans.becker@example.com', '$2a$12$RPEeW6O4dG5cU9xS2YzTclW4X5dO0U6fG1rM3tY4zA5bC6dD7fR', NULL, NULL, NULL, 'suspended', 'member'),
('Ida', 'Hoffmann', 'ida.hoffmann@example.com', '$2a$12$SQFfX7P5eH6dV0yT3ZaUdmX5Y6eP1V7gH2sN4uZ5aB6cD7eE8gS', '+49 173 99887766', 'https://example.com/profiles/ida_h.jpg', 'Harry Potter fan! Also love fantasy and young adult fiction. Happy to trade or lend!', 'active', 'member'),
('Jan', 'Schulz', 'jan.schulz@example.com', '$2a$12$TRGgY8Q6fI7eW1zU4AbVenY6Z7fQ2W8hI3tO5vA6bC7dE8fF9hT', NULL, NULL, NULL, 'active', 'member');

-- Populates the book table with 10 books
-- References publisher(1-10) and language(1-10)
-- Assumption: IDs will be 1-10
INSERT INTO book (publisher_id, language_id, title, subtitle, publication_year, isbn, pages, description) VALUES
(1, 1, 'Der Prozess', NULL, 1925, '9783518188000', 255, 'Ein Romanfragment von Franz Kafka, posthum veröffentlicht.'),
(8, 1, '1Q84', 'Buch 1 & 2', 2010, '9783832161486', 1040, 'Eine surreale Reise in eine Parallelwelt im Jahr 1984.'),
(2, 2, 'The Handmaids Tale', NULL, 1985, '9780385490818', 311, 'Ein dystopischer Roman über eine totalitäre Gesellschaft.'),
(6, 4, 'La Sombra del Viento', NULL, 2001, '9788408043640', 565, 'Ein junger Mann entdeckt ein geheimnisvolles Buch auf dem Friedhof der vergessenen Bücher.'),
(1, 5, 'Lamica geniale', NULL, 2011, '9788866320326', 450, 'Der erste Band der Neapolitanischen Saga über die Freundschaft zweier Frauen.'),
(5, 3, 'Sérotonine', NULL, 2019, '9782072815528', 347, 'Ein Roman über Depression Landwirtschaft und die moderne Gesellschaft.'),
(2, 2, 'Harry Potter and the Philosophers Stone', NULL, 1997, '9780747532699', 223, 'Der erste Band der weltberühmten Zauberer-Saga.'),
(2, 2, 'Nineteen Eighty-Four', '1984', 1949, '9780451524935', 328, 'Ein ikonischer dystopischer Roman über Überwachung und Totalitarismus.'),
(10, 1, 'Eine kurze Geschichte der Menschheit', NULL, 2013, '9783570552698', 528, 'Ein Sachbuch über die Geschichte des Homo sapiens.'),
(1, 1, 'Unterleuten', NULL, 2016, '9783630874876', 672, 'Ein Gesellschaftsroman über einen Konflikt in einem brandenburgischen Dorf.');

-- Links books to their authors (many-to-many relationship)
-- References book(1-10) and author(1-10)
-- Assumption: IDs will be 1-10
INSERT INTO book_author (book_id, author_id) VALUES
(1, 1),  -- Der Prozess -> Franz Kafka
(2, 2),  -- 1Q84 -> Haruki Murakami
(3, 3),  -- The Handmaid's Tale -> Margaret Atwood
(4, 4),  -- La Sombra del Viento -> Carlos Ruiz Zafón
(5, 5),  -- L'amica geniale -> Elena Ferrante
(6, 6),  -- Sérotonine -> Michel Houellebecq
(7, 7),  -- Harry Potter -> J.K. Rowling
(8, 8),  -- 1984 -> George Orwell
(9, 9),  -- Eine kurze Geschichte der Menschheit -> Yuval Noah Harari
(10, 10); -- Unterleuten -> Juli Zeh

-- Links books to their genres (many-to-many relationship)
-- References book(1-10) and genre(1-10)
-- Assumption: IDs will be 1-10
INSERT INTO book_genre (book_id, genre_id) VALUES
(1, 1),  -- Der Prozess -> Roman
(2, 1),  -- 1Q84 -> Roman
(3, 7),  -- The Handmaid's Tale -> Dystopie
(4, 9),  -- La Sombra del Viento -> Historischer Roman
(5, 1),  -- L'amica geniale -> Roman
(6, 10), -- Sérotonine -> Gegenwartsliteratur
(7, 4),  -- Harry Potter -> Fantasy
(8, 7),  -- 1984 -> Dystopie
(9, 5),  -- Eine kurze Geschichte... -> Sachbuch
(10, 10); -- Unterleuten -> Gegenwartsliteratur

-- Creates physical copies of books owned by members
-- References book(1-10) and member(1-10)
-- Assumption: IDs will be 1-10
INSERT INTO book_copy (book_id, owner_id, condition_code, condition_description, acquisition_date, notes, status) VALUES
(1, 1, 'good', 'Some dog-eared pages on chapters 3 and 7. Minor wear on spine. Overall still in good reading condition.', '2020-05-15', 'Purchased at a local bookstore. Has my name written inside the cover.', 'available'),
(2, 2, 'like_new', 'Only read once, no visible signs of use. Pages are crisp and clean.', '2024-12-10', 'Gift from a friend. Happy to lend it out!', 'available'),
(3, 3, 'very_good', 'Minimal wear, slight discoloration on the edges of some pages.', '2019-11-20', NULL, 'available'),
(4, 4, 'acceptable', 'Visible creases on spine, some pages have highlighting and notes in margins.', '2022-04-05', NULL, 'available'),
(5, 6, 'new', NULL, '2025-12-01', NULL, 'available'),
(6, 7, 'good', 'Slight yellowing on page edges due to age. Cover has minor scratches.', '2021-09-14', NULL, 'on_loan'),
(7, 9, 'very_good', 'Hardcover edition in excellent condition. Dust jacket included and well-preserved.', '2021-08-10', 'Part of my collection. First edition!', 'available'),
(8, 10, 'poor', 'Several pages are loose but still attached. Cover is heavily worn. Water damage on pages 45-52 but text is still readable.', '2015-03-22', 'Found at a flea market. Still readable despite condition.', 'on_loan'),
(9, 1, 'like_new', 'Almost perfect condition. Read very carefully. No creases or marks.', '2025-06-18', 'Currently on loan.', 'on_loan'),
(10, 2, 'good', 'Normal wear from regular use. A few coffee stains on cover.', '2023-01-30', NULL, 'unavailable');

-- Creates locations where books can be picked up
-- References member(1-10)
-- Assumption: IDs will be 1-10
-- (SRID 4326 is WGS84, Format: POINT(Longitude Latitude))
INSERT INTO location (member_id, street, house_number, postal_code, city, country_code, coordinates, label) VALUES
(1, 'Hauptstraße', '10', '10115', 'Berlin', 'DE', ST_PointFromText('POINT(13.4050 52.5200)', 4326), 'home'),
(2, 'Marktplatz', '5a', '20095', 'Hamburg', 'DE', ST_PointFromText('POINT(9.9937 53.5511)', 4326), 'home'),
(3, 'Büroallee', '120', '80331', 'München', 'DE', ST_PointFromText('POINT(11.5820 48.1351)', 4326), 'work'),
(4, 'Sonnenweg', '1', '10557', 'Berlin', 'DE', ST_PointFromText('POINT(13.3696 52.5201)', 4326), 'home'),
(5, 'Alter Weg', '22', '50667', 'Köln', 'DE', ST_PointFromText('POINT(6.9573 50.9375)', 4326), 'home'),
(6, 'Bahnhofstraße', '7', '60329', 'Frankfurt am Main', 'DE', ST_PointFromText('POINT(8.6621 50.1069)', 4326), 'pickup'),
(7, 'Rue de la Paix', '15', '75002', 'Paris', 'FR', ST_PointFromText('POINT(2.3316 48.8687)', 4326), 'home'),
(8, 'Nebengasse', '3', '10115', 'Berlin', 'DE', ST_PointFromText('POINT(13.4010 52.5210)', 4326), 'home'),
(9, 'Elbchaussee', '100', '22605', 'Hamburg', 'DE', ST_PointFromText('POINT(9.8976 53.5457)', 4326), 'home'),
(10, 'Turmstraße', '30', '10559', 'Berlin', 'DE', ST_PointFromText('POINT(13.3470 52.5234)', 4326), 'work');

-- Defines when and where book copies are available for borrowing
-- References book_copy(1-10) and location(1-10)
-- Assumption: IDs will be 1-10
INSERT INTO availability (copy_id, location_id, available_from, available_to, max_duration_days, shipping_possible, status) VALUES
(1, 1, '2026-01-01', '2026-12-31', 21, FALSE, 'active'),
(2, 2, '2026-01-01', '2026-12-31', 14, TRUE, 'active'),
(3, 3, '2026-02-01', '2026-10-31', 10, FALSE, 'active'),
(4, 4, '2026-01-01', '2026-12-31', 30, TRUE, 'active'),
(5, 6, '2026-01-01', '2026-12-31', 14, FALSE, 'active'),
(6, 7, '2026-01-01', '2026-12-31', 14, TRUE, 'active'),
(7, 9, '2026-01-01', '2026-12-31', 14, TRUE, 'active'),
(8, 10, '2026-01-01', '2026-12-31', 7, FALSE, 'active'),
(9, 1, '2026-01-01', '2026-12-31', 14, FALSE, 'active'),
(10, 2, '2026-01-01', '2026-06-30', 14, TRUE, 'paused');

-- Creates loan transactions showing the borrowing process
-- References availability(1-10) and member(1-10)
-- Assumption: IDs will be 1-10
INSERT INTO loan (availability_id, lender_id, borrower_id, request_date, start_date, planned_end_date, actual_end_date, status, cancellation_date, cancellation_reason) VALUES
-- Loan 1: Completed loan (returned), all dates filled
(1, 1, 2, '2025-09-25 14:30:00', '2025-10-01', '2025-10-22', '2025-10-20', 'returned', NULL, NULL),
-- Loan 2: Completed loan (returned), returned on time
(2, 2, 3, '2025-09-28 09:15:00', '2025-10-05', '2025-10-19', '2025-10-18', 'returned', NULL, NULL),
-- Loan 3: Completed loan (returned), returned slightly late
(3, 3, 4, '2025-10-20 16:45:00', '2025-11-01', '2025-11-11', '2025-11-13', 'returned', NULL, NULL),
-- Loan 4: Completed loan (returned), returned early
(4, 4, 6, '2025-10-28 11:20:00', '2025-11-05', '2025-12-05', '2025-12-01', 'returned', NULL, NULL),
-- Loan 5: Completed loan (returned)
(5, 6, 7, '2025-11-01 08:00:00', '2025-11-10', '2025-11-24', '2025-11-23', 'returned', NULL, NULL),
-- Loan 6: Currently active loan
(6, 7, 9, '2026-03-05 10:30:00', '2026-03-10', '2026-03-24', NULL, 'active', NULL, NULL),
-- Loan 7: Requested but not yet accepted
(7, 9, 10, '2026-03-14 13:45:00', NULL, NULL, NULL, 'requested', NULL, NULL),
-- Loan 8: Overdue loan
(8, 10, 1, '2026-02-15 15:20:00', '2026-02-20', '2026-03-01', NULL, 'overdue', NULL, NULL),
-- Loan 9: Currently active
(9, 1, 4, '2026-03-01 12:00:00', '2026-03-05', '2026-03-19', NULL, 'active', NULL, NULL),
-- Loan 10: Cancelled loan with reason
(10, 2, 1, '2026-03-03 17:30:00', NULL, NULL, NULL, 'cancelled', '2026-03-04', 'Borrower found the book elsewhere and cancelled the request.');

-- Creates ratings for completed loan transactions
-- References loan(1-10) and member(1-10)
-- Ratings for the 5 'returned' loans (ID 1-5)
-- Assumption: IDs will be 1-10
INSERT INTO rating (loan_id, rater_id, rated_member_id, stars, comment, created_at) VALUES
-- Rating 1: Lender rates borrower for loan 1
(1, 1, 2, 5, 'Excellent borrower! Book was returned on time and in perfect condition. Great communication throughout.', '2025-10-21 10:15:00'),
-- Rating 2: Borrower rates lender for loan 1
(1, 2, 1, 4, 'Book was as described. Pickup was easy and flexible. Would borrow again!', '2025-10-21 14:30:00'),
-- Rating 3: Lender rates borrower for loan 2
(2, 2, 3, 5, 'Very reliable borrower. Returned the book a day early. Highly recommend!', '2025-10-19 09:00:00'),
-- Rating 4: Borrower rates lender for loan 2
(2, 3, 2, 5, 'Perfect transaction. Thank you!', '2025-10-19 11:20:00'),
-- Rating 5: Lender rates borrower for loan 3
(3, 3, 4, 3, 'Book was returned a bit late, but borrower communicated about it. Book condition was good.', '2025-11-14 16:30:00'),
-- Rating 6: Borrower rates lender for loan 3
(3, 4, 3, 4, 'Good book condition. Pickup location was convenient. Would recommend!', '2025-11-14 18:00:00'),
-- Rating 7: Lender rates borrower for loan 4
(4, 4, 6, 5, NULL, '2025-12-02 08:45:00'),
-- Rating 8: Borrower rates lender for loan 4
(4, 6, 4, 5, 'Very friendly and accommodating lender. Fast response time. Loved the book!', '2025-12-02 10:00:00'),
-- Rating 9: Lender rates borrower for loan 5
(5, 6, 7, 4, 'Good borrower. Book returned on time and in good condition. Minor coffee stain on one page but acceptable.', '2025-11-24 15:20:00'),
-- Rating 10: Borrower rates lender for loan 5
(5, 7, 6, 5, 'Amazing experience! The book was even better than expected. Super friendly lender. 10/10 would borrow again!', '2025-11-24 16:45:00');