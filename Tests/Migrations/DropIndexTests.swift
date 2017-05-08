import XCTest
import Nimble
@testable import Squeal

class DropIndexTests: SquealMigrationTestCase {

    func test_dropIndex() {
        // SETUP: A table and an index
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
                
                v.createIndex("people_names", on:"people", columns:["name"], partialExpr:"name != ''", unique:true)
            }
            
            s.version(2) { v in
                v.dropIndex("people_names")
            }
        }
        
        // TEST: Schema version no longer has the index
        expect(schema.latestVersion).notTo(haveIndex("people_names"))
        expect(schema.version(1)).to(haveIndex("people_names"))
        
        // -----------------------------------------------------------------------------------------
        // SETUP: A database
        
        let db = newDatabaseAtVersion(1, ofSchema: schema)
        expect(db).to(haveIndex("people_names"))

        // TEST: Migrate the database
        migrate(db, schema: schema)
        
        // VERIFY: Migration removes the index from the database
        expect(db).notTo(haveIndex("people_names"))
    }

}
