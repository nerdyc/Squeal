import XCTest
import Squeal
import Nimble

class ExecuteTests: SquealMigrationTestCase {

    func test_executeUpdate() {
        // SETUP: A schema with an 'execute' step within a migration.
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.execute { db in
                    // remove whitespace
                    try db.update("people", set: "name = upper(trim(name))")
                }
            }
        }
        
        // SETUP: A database at version 1
        let db = newDatabaseAtVersion(1, ofSchema: schema)
        expect(try db.tableInfoForTableNamed("people")?.columnNames) == ["id", "name"]
        
        let names = [
            " Abby Walker ",
            "Bill Murphy ",
            "  Clara Bow",
        ]
        for name in names {
            try! db.insertInto(
                "people",
                values: [ "name": name ]
            )
        }
        
        // TEST: Perform the migration
        migrate(db, schema: schema)
        
        // VERIFY: Execute step was performed
        var fetchedNames = [String]()
        expect {
            fetchedNames = try db.select(from:"people", columns: ["name"]) { $0.stringValue("name") ?? "" }
        }.notTo(throwError())
        
        expect(fetchedNames) == [
            "ABBY WALKER",
            "BILL MURPHY",
            "CLARA BOW"
        ]
        
    }

}
