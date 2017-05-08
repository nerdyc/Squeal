import XCTest
import Nimble
@testable import Squeal

class CreateTableTests: SquealMigrationTestCase {

    func test_createTable() {
        // SETUP: A table
        let schema = defineTable("people") { people in
            people.primaryKey("id")
            people.column("name", type: .Text)
        }
        
        // VERIFY: Table exists in the schema
        expect(schema["people"]).to(haveColumns("id", "name"))
        expect(schema["people"]?.definitions) == [
            "\"id\" INTEGER PRIMARY KEY",
            "\"name\" TEXT"
        ]
        
        // VERIFY: Migration succeeds
        let db = Database()
        migrate(db, schema: schema)
        
        // VERIFY: Table is created correctly
        expect(tableInfoWithName("people", inDatabase: db)).to(haveColumns("id", "name"))
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Constraints

    func test_createTable_withConstraints() {
        // TEST: Define a table with a constraint
        let schema = defineTable("people") { t in
            t.primaryKey("id")
            t.column("name", type: .Text)
            t.constraint("UNIQUE (name)", named:"unique_name")
        }
        
        // VERIFY: constraint is generated
        expect(schema["people"]?.definitions).to(contain(
            "CONSTRAINT \"unique_name\" UNIQUE (name)"
        ))

        // VERIFY: Migration doesn't fail
        expect {
            try schema.migrate(Database())
        }.notTo(throwError())
    }
    
}


