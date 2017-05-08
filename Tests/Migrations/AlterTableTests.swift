import XCTest
import Nimble
@testable import Squeal

class AlterTableTests: SquealMigrationTestCase {

    // ---------------------------------------------------------------------------------------------
    // MARK: Add Column
    
    func test_alterTable_addColumn() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    
                    people.addColumn("email", .Text, "DEFAULT NULL")
                    
                }
            }
        }
        
        // VERIFY: Column is added to schema
        expect(schema["people"]).to(haveColumns("id", "name", "email"))
        
        // VERIFY: Database migration succeeds
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        migrate(db, schema: schema)
        
        expect(tableInfoWithName("people", inDatabase: db)).to(haveColumns("id", "name", "email"))
    }
    
    func test_alterTable_addColumn_withInitialValue() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    
                    // A new NOT NULL column, with an initial value. Normally all added columns need
                    // to be nullable, or have a single default value. This form allows an expression
                    // to be used to set an initial value.
                    people.addColumn(
                        "email",
                        type:.Text,
                        constraints: ["NOT NULL"],
                        setValue: "printf(\"%s@domain.com\", lower(name))"
                    )
                    
                }
            }
        }
        
        // VERIFY: Column is added to schema
        expect(schema["people"]).to(haveColumns("id", "name", "email"))
        
        // -----------------------------------------------------------------------------------------
        
        // SETUP: A database with existing values
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        expect {
            try db.insertInto(
                "people",
                values: [
                    "name": "Abby",
                ]
            )
            try db.insertInto(
                "people",
                values: [
                    "name": "Bill"
                ]
            )
            try db.insertInto(
                "people",
                values: [
                    "name": "Clara"
                ]
            )
            return nil
        }.notTo(throwError())
        
        // VERIFY: Database migration succeeds
        migrate(db, schema: schema)
        
        // VERIFY: Column is added
        expect(tableInfoWithName("people", inDatabase: db)).to(haveColumns("id", "name", "email"))
        
        // VERIFY: Column is populated with initial values
        let emails = try! db.selectAll("SELECT email FROM people ORDER BY email") { $0.stringValueAtIndex(0) ?? "" }
        expect(emails) == [ "abby@domain.com", "bill@domain.com", "clara@domain.com" ]
    }

    /// Tests that columns are added properly after altering another column. This is necessary since
    /// `alterTable` will collapse alterations into fewer updates if possible.
    func test_alterTable_addColumnAfterAltering() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    
                    people.alterColumn("name", setConstraints:["UNIQUE", "NOT NULL"])
                    people.addColumn("email", .Text, "DEFAULT NULL")
                    
                }
            }
        }
        
        // VERIFY: Column is added to schema
        expect(schema["people"]).to(haveColumns("id", "name", "email"))
        
        // VERIFY: Database migration succeeds
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        migrate(db, schema: schema)
        
        expect(tableInfoWithName("people", inDatabase: db)).to(haveColumns("id", "name", "email"))
    }
    // ---------------------------------------------------------------------------------------------
    // MARK: Drop Column

    func test_alterTable_dropColumn() {
        // SETUP: A schema containing a migration that drops a column
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name",    .Text, "NOT NULL")
                    people.column("email",   .Text, "NOT NULL DEFAULT ''")
                    people.column("age",     .Integer, "DEFAULT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    people.dropColumn("age")
                }
            }
        }
        
        // VERIFY: The column is removed in the schema version
        expect(schema["people"]).notTo(beNil())
        expect(schema["people"]?.columnNames) == ["id", "name", "email"]
        
        // SETUP: A database
        let db = newDatabaseAtVersion(1, ofSchema: schema)
        expect {
            try db.insertInto(
                "people",
                values: [
                    "name": "Abby",
                    "email": "abby@gastrobot.xyz",
                    "age": 8
                ]
            )
            try db.insertInto(
                "people",
                values: [
                    "name": "Bill",
                    "email": "bill@gastrobot.xyz",
                    "age": 16
                ]
            )
            return nil
        }.notTo(throwError())
        
        // TEST: Migrate the database
        migrate(db, schema: schema)
        
        // VERIFY: Column is removed from the database
        expect(try db.tableInfoForTableNamed("people")).to(haveColumns("id", "name", "email"))
    }
    
    func test_alterTable_dropColumnAfterAltering() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                    people.column("email", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    
                    people.alterColumn("name", setConstraints:["NOT NULL", "DEFAULT 'anonymous'"], setValue:"upper(name)")
                    people.dropColumn("email")
                    
                }
            }
        }
        
        // VERIFY: Column is dropped from schema
        expect(schema["people"]).to(haveColumns("id", "name"))
        
        // -----------------------------------------------------------------------------------------
        // SETUP: A database to migrate, with sample data
        
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        expect {
            try db.insertInto(
                "people",
                values: [
                    "name": "Abby",
                    "email": "abby@gastrobot.xyz",
                ]
            )
            try db.insertInto(
                "people",
                values: [
                    "name": "Bill",
                    "email": "bill@gastrobot.xyz"
                ]
            )
            return nil
        }.notTo(throwError())
        
        // TEST: Migrate the data
        migrate(db, schema: schema)
        
        // VERIFY: Columns are altered
        let peopleInfo = tableInfoWithName("people", inDatabase: db)
        expect(peopleInfo?.columnNames) == ["id", "name"]
        expect(peopleInfo?["name"]?.notNull) == true
        expect(peopleInfo?["name"]?.defaultValue) == "'anonymous'"
        
        // VERIFY: Data is correct
        let names = try! db.selectAll("SELECT name FROM people") { $0.stringValueAtIndex(0) ?? "" }
        expect(names) == [ "ABBY", "BILL" ]
    }

    // ---------------------------------------------------------------------------------------------
    // MARK: Alter Column
    
    func test_alterTable_alterColumn() {
        // SETUP: A schema containing a migration that drops a column
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name",    .Text, "NOT NULL")
                    people.column("email",   .Text, "NOT NULL DEFAULT ''")
                    people.column("age",     .Integer, "DEFAULT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    people.alterColumn("age",
                                       renameTo:       "ageISODuration",
                                       changeTypeTo:   .Text,
                                       setConstraints: ["NOT NULL", "DEFAULT '0s'"],
                                       setValue:       "printf(\"P%dM\", age * 12)")
                }
            }
        }
        
        // VERIFY: Schema is updated
        expect(schema["people"]?.columnNames) == ["id", "name", "email", "ageISODuration"]
        expect(schema["people"]?["ageISODuration"]?.type) == .Text
        expect(schema["people"]?["ageISODuration"]?.constraints) == ["NOT NULL", "DEFAULT '0s'"]
        
        // -----------------------------------------------------------------------------------------
        // SETUP: A database with some test data
        
        let db = newDatabaseAtVersion(1, ofSchema: schema)
        expect {
            try db.insertInto(
                "people",
                values: [
                    "name": "Abby",
                    "email": "abby@gastrobot.xyz",
                    "age": 8
                ]
            )
            try db.insertInto(
                "people",
                values: [
                    "name": "Bill",
                    "email": "bill@gastrobot.xyz",
                    "age": 16
                ]
            )
            return nil
        }.notTo(throwError())
        
        // TEST: Migrate the database
        migrate(db, schema: schema)
        
        // VERIFY: Column is migrated
        let tableInfo = try! db.tableInfoForTableNamed("people")
        expect(tableInfo?.columnNames) == ["id", "name", "email", "ageISODuration"]
        expect(tableInfo?["ageISODuration"]?.type) == "TEXT"
        expect(tableInfo?["ageISODuration"]?.notNull) == true
        expect(tableInfo?["ageISODuration"]?.defaultValue) == "'0s'"
        
        // VERIFY: Values are transformed
        let ages = try! db.selectAll("SELECT ageISODuration FROM people") { $0.stringValueAtIndex(0) ?? "" }
        expect(ages) == [ "P96M", "P192M" ]
    }

    ///
    /// Tests that multiple columns are altered properly together. Multiple alterations should be
    /// collapsed into a single update for performance.
    ///
    func test_alterTable_alterMultipleColumns() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                    people.column("email", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    
                    people.alterColumn("name", setConstraints:["NOT NULL", "DEFAULT ''"])
                    people.alterColumn("email", renameTo: "email_address", setValue:"upper(email)")
                    
                }
            }
        }
        
        // VERIFY: Columns are altered in the schema
        expect(schema["people"]).to(haveColumns("id", "name", "email_address"))
        
        // -----------------------------------------------------------------------------------------
        // SETUP: A database to migrate, with sample data
        
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        expect {
            try db.insertInto(
                "people",
                values: [
                    "name": "Abby",
                    "email": "abby@gastrobot.xyz",
                ]
            )
            try db.insertInto(
                "people",
                values: [
                    "name": "Bill",
                    "email": "bill@gastrobot.xyz"
                ]
            )
            return nil
        }.notTo(throwError())
        
        // TEST: Migrate the data
        migrate(db, schema: schema)
        
        // VERIFY: Columns are altered
        let peopleInfo = tableInfoWithName("people", inDatabase: db)
        expect(peopleInfo?.columnNames) == ["id", "name", "email_address"]
        expect(peopleInfo?["name"]?.notNull) == true
        expect(peopleInfo?["name"]?.defaultValue) == "''"

        expect(peopleInfo?["email_address"]?.notNull) == true
        expect(peopleInfo?["email_address"]?.defaultValue).to(beNil())

        // VERIFY: Data is correct
        let names = try! db.selectAll("SELECT name FROM people") { $0.stringValueAtIndex(0) ?? "" }
        expect(names) == [ "Abby", "Bill" ]
        
        let emails = try! db.selectAll("SELECT email_address FROM people") { $0.stringValueAtIndex(0) ?? "" }
        expect(emails) == [ "ABBY@GASTROBOT.XYZ", "BILL@GASTROBOT.XYZ" ]
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Indexes
    
    func test_indexesArePreservedWhenATableColumnIsRenamed() {
        // SETUP: A migration that alters indexed columns
        let schema = Schema { s in
            
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
                
                v.createIndex("people_names", on: "people", columns: ["name"], unique: true)
            }
            
            s.version(2) { v in
                
                v.alterTable("people") { people in
                    people.alterColumn("name", renameTo: "full_name")
                }
                
            }
            
        }
        
        // VERIFY: Index is updated in the schema
        let index = schema.latestVersion?.indexNamed("people_names")
        expect(index?.columns) == ["full_name"]
        expect(index?.unique) == true
        
        // -----------------------------------------------------------------------------------------
        // SETUP: A database to migrate
        
        let db = newDatabaseAtVersion(1, ofSchema: schema)
        
        // TEST: Migrate the database
        migrate(db, schema: schema)
        
        // VERIFY: Index is remapped
        let dbIndex = try! db.tableInfoForTableNamed("people")?.indexNamed("people_names")
        expect(dbIndex).notTo(beNil())
        expect(dbIndex?.name) == "people_names"
        expect(dbIndex?.columnNames) == [ "full_name" ]
        expect(dbIndex?.isUnique) == true
        
        expect(db).to(haveIndex("people_names", on: "people", columns: ["full_name"]))
    }
    
    func test_indexesAreRemovedWhenATableColumnIsDropped() {
        // SETUP: A migration that removes an indexed column
        let schema = Schema { s in
            
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                    people.column("email", .Text, "NOT NULL")
                }
                
                v.createIndex("people_names", on: "people", columns: ["name"])
                v.createIndex("people_emails", on: "people", columns: ["email"], unique: true)
            }
            
            s.version(2) { v in
                
                // drop an indexed column
                v.alterTable("people") { people in
                    people.dropColumn("name")
                }
            }
            
        }
        
        // VERIFY: Index is removed from schema
        expect(schema.latestVersion?.indexNames) == ["people_emails"]
        
        // -----------------------------------------------------------------------------------------
        // SETUP: A database to migrate
        
        let db = newDatabaseAtVersion(1, ofSchema: schema)
        
        // TEST: Migrate the database
        migrate(db, schema: schema)
        
        // VERIFY: Index is removed in the db
        expect(db.schema.indexNames) == ["people_emails"]
        expect(db).to(haveIndex("people_emails", on: "people", columns: ["email"]))
    }
    
    func test_indexesAreUpdatedWhenATableIsRenamed() {
        // SETUP: A migration that renames a table with indexed columns
        let schema = Schema { s in
            
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                    people.column("email", .Text, "NOT NULL")
                }
                
                v.createIndex("people_names", on: "people", columns: ["name"])
                v.createIndex("people_emails", on: "people", columns: ["email"], unique: true)
            }
            
            s.version(2) { v in
                v.renameTable("people", to: "contacts")
            }
            
        }
        
        // VERIFY: Indexes are updated in the schema
        expect(schema.latestVersion?.indexNames) == ["people_names", "people_emails"]
        expect(schema.latestVersion?.indexNamed("people_names")?.tableName) == "contacts"
        expect(schema.latestVersion?.indexNamed("people_emails")?.tableName) == "contacts"
        
        // TEST: Migrate the database
        let db = Database()
        migrate(db, schema: schema)
        
        // VERIFY: Indexes are updated int he database
        expect(db).to(haveIndex("people_names", on: "contacts", columns: ["name"]))
        expect(db).to(haveIndex("people_emails", on: "contacts", columns: ["email"]))
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Constraints
    
    func test_addTableConstraint() {
        // TEST: A migration that adds a table constraint
        let schema = Schema { s in
            
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                    
                    people.constraint("CHECK (length(trim(name)) > 0)", named:"non_empty_name")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    people.addConstraint("UNIQUE (name)", named:"unique_name")
                }
            }
        }
        
        // VERIFY: Constraint is added in the schema
        expect(schema["people"]?.constraints.map { $0.definition }) == [
            "CONSTRAINT \"non_empty_name\" CHECK (length(trim(name)) > 0)",
            "CONSTRAINT \"unique_name\" UNIQUE (name)"
        ]
        
        // TEST: Migration succeeds
        let db = Database()
        expect {
            try schema.migrate(db)
        }.notTo(throwError())
        
        // VERIFY: Constraints are added when migrated.
        expect {
            try db.insertInto(
                "people",
                values:[
                    "name": "  "
                ]
            )
        }.to(throwError())
        
        expect {
            try db.insertInto(
                "people",
                values:[
                    "name": "Abby"
                ]
            )
        }.notTo(throwError())
    }

    func test_dropTableConstraint() {
        // TEST: A migration that drops a table constraint
        let schema = Schema { s in
            
            s.version(1) { v in
                v.createTable("people") { people in
                    people.column("id", .Integer, "NOT NULL")
                    people.column("name", .Text, "NOT NULL")
                    
                    people.constraint("CHECK (length(trim(name)) > 0)", named:"non_empty_name")
                    people.constraint("UNIQUE (name)")
                    people.constraint("PRIMARY KEY (id)")
                }
            }
            
            s.version(2) { v in
                v.alterTable("people") { people in
                    people.dropConstraint(named:"non_empty_name")
                    people.dropConstraint("UNIQUE (name)")
                }
            }
        }
        
        // VERIFY: Constraint is dropped in the schema
        expect(schema["people"]?.constraints.map({ $0.definition })) == [
            "PRIMARY KEY (id)"
        ]
        
        // TEST: Migration succeeds
        let db = Database()
        expect {
            try schema.migrate(db)
        }.notTo(throwError())
    

        // VERIFY: Constraints are removed by the migration
        expect {
            try db.insertInto(
                "people",
                values:[
                    "name": ""
                ]
            )
        }.notTo(throwError())
        
        expect {
            try db.insertInto(
                "people",
                values:[
                    "name": "Abby"
                ]
            )
            try db.insertInto(
                "people",
                values:[
                    "name": "Abby"
                ]
            )
            return nil
        }.notTo(throwError())
    }

}
