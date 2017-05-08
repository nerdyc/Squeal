import XCTest
import Nimble
@testable import Squeal

class DropTableTests: SquealMigrationTestCase {

    func test_dropTable() {
        // TEST: Create a migration that drops a table
        let schema = Schema(identifier:#function) { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", type: .Text)
                }
                v.createTable("pets") { pets in
                    pets.primaryKey("id")
                    pets.column("type", type: .Text)
                }
            }
            
            s.version(2) { v in
                v.dropTable("pets")
            }
        }
        
        // VERIFY: Table is dropped from latest schema
        expect(schema.version(1)).to(haveTables("people", "pets"))
        expect(schema.version(2)).to(haveTables("people"))
        
        // TEST: Run the Migration
        let db = Database()
        expect {
            try schema.migrate(db, toVersion:1)
        }.notTo(throwError())
        
        expect {
            try schema.migrate(db)
        }.notTo(throwError())
        
        // VERIFY: Table is removed
        expect(db).to(haveTables("people"))
    }
    
}
