import XCTest
import Nimble
@testable import Squeal

class RenameTableTests: SquealMigrationTestCase {

    func test_renameTable() {
        // TEST: A migration that renames a table
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
            }
            
            s.version(2) { v in
                v.renameTable("people", to:"persons")
            }
        }
        
        // VERIFY: Table is renamed
        expect(schema.version(1)).to(haveTables("people"))
        expect(schema.version(2)).to(haveTables("persons"))
        
        // VERIFY: Structure is preserved
        expect(schema["persons"]).to(haveColumns("id", "name"))
        
        // TEST: Migration
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        migrate(db, schema: schema)
        
        // VERIFY: Table is renamed
        expect(db).to(haveTables("persons"))
    }
    
}
