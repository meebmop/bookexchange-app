# BookExchange Datenbank

Relationale Datenbank für eine Buchtausch-Plattform, implementiert in MariaDB.

Dieses Projekt wurde im Rahmen des Moduls  
**DLBDSPBDM01_D – Datenbanken und Datenmanagement** entwickelt.

Die Datenbank modelliert eine Plattform, auf der Mitglieder Bücher anbieten, ausleihen und nach einer erfolgreichen Ausleihe gegenseitig bewerten können.

---

## Features

Die Datenbank implementiert mehrere fortgeschrittene Datenbankkonzepte:

- Relationales Schema mit normalisierten Tabellen
- Foreign-Key- und CHECK-Constraints zur Sicherstellung der Datenintegrität
- Trigger zur Durchsetzung von Geschäftsregeln
- Audit-Logging für administrative Änderungen
- Rollenbasiertes Berechtigungsmodell
- Privacy-Views zum Schutz sensibler Daten
- Analytische Views für Reporting und Data-Mart-Auswertungen
- Test-Szenarien zur Validierung von Constraints und Triggern

---

## Projektstruktur

```
sql/
├── 01_Schema.sql
├── 02_Seed_Data.sql
├── 03_Triggers.sql
├── 04_Views.sql
├── 05_Role_Privileges.sql
└── 06_Tests.sql
```

| Datei | Beschreibung |
|---|---|
| `01_Schema.sql` | Erstellt Datenbank, Tabellen und Constraints |
| `02_Seed_Data.sql` | Fügt Beispiel-Daten ein |
| `03_Triggers.sql` | Implementiert Geschäftsregeln über Trigger |
| `04_Views.sql` | Erstellt Privacy- und Analyse-Views |
| `05_Role_Privileges.sql` | Implementiert Rollen und Berechtigungen |
| `06_Tests.sql` | Enthält Test-Szenarien zur Überprüfung der Datenbank |

---

## Installation

Die Installation kann mit jedem SQL-Client erfolgen, z. B.:

- HeidiSQL
- Visual Studio Code (SQL Extension)
- MariaDB Kommandozeile

Die Datenbank wird automatisch durch das erste Skript erstellt.

### SQL-Skripte in folgender Reihenfolge ausführen:

```
01_Schema.sql
02_Seed_Data.sql
03_Triggers.sql
04_Views.sql
05_Role_Privileges.sql
06_Tests.sql
```

Eine detaillierte Installationsanleitung befindet sich im Ordner:

```
docs/Gross-Marie_IU14106516_DLBDSPBDM01_D_ Bearbeitungs-Reflexionsphase_SQL_Installationsanleitung.pdf
```

---

## Überprüfung der Installation

Nach der Installation kann überprüft werden, ob alle Datenbankobjekte korrekt erstellt wurden:

```sql
USE bookexchange;

SHOW TABLES;
SHOW TRIGGERS;
SHOW FULL TABLES WHERE TABLE_TYPE = 'VIEW';
```

Wenn alle Abfragen Ergebnisse liefern, wurde die Installation erfolgreich durchgeführt.

---

## Rollenmodell

Die Datenbank implementiert zwei Rollen:

### app_member

Standardrolle für normale Benutzer der Plattform.

Berechtigungen:
- Lesen von Katalogdaten (Bücher, Autoren, Genres)
- Erstellen und Verwalten von Ausleihen
- Verwaltung des eigenen Profils
- Zugriff auf Privacy-Views

Direkter Zugriff auf sensible personenbezogene Daten ist eingeschränkt.

### app_admin

Administrative Rolle mit erweiterten Rechten.

Berechtigungen:
- Vollständige DML-Zugriffe auf zentrale Tabellen
- Zugriff auf Analyse-Views
- Zugriff auf Audit-Logs

Administratoren besitzen **keine DDL-Rechte** und können die Datenbankstruktur nicht verändern.

---

## Audit Logging

Administrative Änderungen an der Tabelle `member` werden automatisch protokolliert.

Der Trigger `trg_member_audit_update` speichert folgende Informationen in der Tabelle `admin_audit_log`:

- Alte und neue Werte
- Ausführender Benutzer
- Zeitstempel

---

## Analytische Views

Für Reporting und Analyse wurden mehrere Data-Mart-Views implementiert:

| View | Beschreibung |
|---|---|
| `vw_dm_book_dim` | Buch-Dimension |
| `vw_dm_member_dim` | Mitglieds-Dimension |
| `vw_dm_loan_fact` | Faktentabelle für Ausleihen |
| `dm_book_performance` | Performance-Kennzahlen pro Buch |
| `dm_member_stats` | Aktivitäts- und Trust-Score pro Mitglied |
| `vw_report_loans_per_city_month` | Monatliche Ausleihen pro Stadt |

---

## Test-Szenarien

Die Datei `06_tests.sql` enthält mehrere Testfälle.

### Happy Path

Testet den vollständigen Ablauf einer Ausleihe:

```
Suche → Anfrage → Annahme → Rückgabe → Bewertung
```

### Constraint-Tests

Validiert unter anderem:
- Ungültige Bewertungen
- Doppelte Bewertungen
- Ungültige Datumsbereiche
- Fehlerhafte ISBN-Werte

### Trigger-Tests

Überprüft Geschäftsregeln, z. B.:
- Verhinderung überlappender Verfügbarkeiten
- Blockierung ungültiger Ausleihen
- Audit-Logging

### Rollen-Tests

Validiert das Least-Privilege-Prinzip für `app_member` und `app_admin`.

---

## Technologien

- MariaDB
- SQL
- HeidiSQL (Entwicklungsumgebung)

---

## Autor

Marie Groß (Martrikelnummer: IU14106516) 
IU Internationale Hochschule

Studiengang: Informatik  
Modul: **DLBDSPBDM01_D – Datenbanken und Datenmanagement**
