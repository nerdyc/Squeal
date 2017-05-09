import XCTest
import Squeal
import Nimble

class SchemaTests: SquealMigrationTestCase {

    func test_databaseVersionIsUpdatedAfterMigration() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            s.version(2) { v in
                v.createTable("contacts") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
        }
        
        let db = Database()
        
        // -----------------------------------------------------------------------------------------
        // TEST: Migrate the database

        expect {
            try schema.migrate(db, toVersion: 1)
        }.notTo(throwError())
        
        // VERIFY: Version number is updated
        
        expect(db.schema.tableNames) == ["people"]
        expect(try db.queryUserVersionNumber()) == 1
        
        // -----------------------------------------------------------------------------------------
        // TEST: Migrate to a later version
        
        expect {
            try schema.migrate(db, toVersion: 2)
        }.notTo(throwError())
        
        // VERIFY: Version is updated again
        expect(try db.queryUserVersionNumber()) == 2
    }

    func test_databaseIsRolledBackIfMigrationFails() {
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
                v.execute { db in
                    // this will fail since the column name is wrong
                    try db.insert(into:"people", values: [ "full_name": "Heidi"])
                }
            }
        }
        
        let db = Database()
        expect {
            try schema.migrate(db)
        }.to(throwError())
        
        expect(db.schema.tableNames) == []
    }
    
    func test_errorIsThrownIfVersionIsInvalid() {
        // SETUP:
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            s.version(3) { v in
                v.createTable("contacts") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
        }
        
        let db = Database()
        
        // TEST: Try to migrate to a number greater than the current schema version
        expect {
            try schema.migrate(db, toVersion: 2)
        }.to(throwError())
        
        // TEST: Try to migrate to a number greater than the current schema version
        expect {
            try schema.migrate(db, toVersion: 4)
        }.to(throwError())

        // TEST: Try to migrate to a negative version
        expect {
            try schema.migrate(db, toVersion: -1)
        }.to(throwError())
    }
    
    func test_migrateResetsTheDatabaseIfCurrentVersionIsUnknown() {
        // SETUP: A Schema
        let schema = Schema { s in
            s.version(3) { v in
                v.createTable("contacts") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
        }
        
        // SETUP: A database with an unknown version (2), and schema
        let db = Database()
        expect { try db.createTable("unknowns", definitions: [ "name TEXT" ]) }.notTo(throwError())
        expect { try db.updateUserVersionNumber(2) }.notTo(throwError())
        
        // TEST: Migrate the database
        migrate(db, schema: schema, options: .ResetOldDatabaseVersions)
        
        // VERIFY: Database is reset and migration performed
        expect(db).to(haveTables("contacts"))
        expect(try db.queryUserVersionNumber()) == 3
    }
    
    func test_migrateReturnsTrueIfMigratedFalseIfNoMigrationNeeded() {
        // SETUP:
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            s.version(2) { v in
                v.createTable("contacts") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
        }
        
        let db = Database()
        
        // TEST: Migrate to the current version (0)
        var returnValue:Bool = true
        expect {
            returnValue = try schema.migrate(db, toVersion: 0)
        }.notTo(throwError())
        
        // VERIFY: returns false, since version matches.
        expect(returnValue) == false
        
        // -----------------------------------------------------------------------------------------
        // TEST: Migrate to a newer version
        
        expect {
            returnValue = try schema.migrate(db)
        }.notTo(throwError())
        
        expect(returnValue) == true
        
        // -----------------------------------------------------------------------------------------
        // TEST: Migrate to the same version again
        
        expect {
            returnValue = try schema.migrate(db)
        }.notTo(throwError())
        
        expect(returnValue) == false
        
    }

    // ---------------------------------------------------------------------------------------------
    // MARK: Reset
    
    func test_resettingADatabase() {
        // SETUP: A schema
        let schema = Schema { s in
            
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id", autoincrement: true)
                    people.column("name", .Text, "NOT NULL")
                    people.column("email_count", .Integer, "NOT NULL DEFAULT 0")
                }
                
                v.createIndex("people_unique_name", on: "people", columns: [ "name" ])
                
                v.createTable("emails") { emails in
                    emails.column("address", .Text, "UNIQUE NOT NULL")
                    emails.constraint("PRIMARY KEY (address)")
                    
                    emails.column("person_id", .Integer, "NOT NULL REFERENCES people(id)")
                }
                
                v.execute { db in
                    try db.execute("CREATE TRIGGER update_email_count AFTER INSERT ON emails BEGIN\nUPDATE people SET email_count = email_count+1 WHERE people.id = NEW.person_id; END;")
                }
                
            }

        }
        
        // SETUP: A migrated database
        let db = Database()
        migrate(db, schema: schema)
        
        expect {
            try db.insert(into:"people", values: [ "name": "Alice" ])
            try db.insert(into:"people", values: [ "name": "Bob" ])
            
            try db.insert(into:"emails", values: [
                "address": "alice@example.com",
                "person_id": 1
            ])
            return nil
        }.notTo(throwError())
        
        // TEST: Reset the database
        expect {
            try schema.reset(db)
        }.notTo(throwError())
        
        // VERIFY: All tables, indexes, and triggers are removed.
        expect(db.schema.tableNames) == ["sqlite_sequence"]
        
        // VERIFY: Database version number is 0
        expect(try db.queryUserVersionNumber()) == 0
    }
    
}
