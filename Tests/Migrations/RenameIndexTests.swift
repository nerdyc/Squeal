import XCTest
import Nimble
@testable import Squeal

class RenameIndexTests: SquealMigrationTestCase {

    func test_renameIndex() {
        // TEST: A migration that renames an index
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
                
                v.createIndex("people_name", on: "people", columns: ["name"])
            }
            
            s.version(2) { v in
                v.renameIndex("people_name", to:"names_of_people")
            }
        }
        
        // VERIFY: Table is renamed
        expect(schema.version(1)).to(haveIndex("people_name"))
        expect(schema.version(2)).to(haveIndex("names_of_people"))
        
        // VERIFY: Structure is preserved
        expect(schema.latestVersion?.indexNamed("names_of_people")?.columns) == ["name"]
        expect(schema.latestVersion?.indexNamed("names_of_people")?.tableName) == "people"
        
        // TEST: Migration
        let db = newDatabaseAtVersion(1, ofSchema:schema)
        migrate(db, schema: schema)
        
        // VERIFY: Table is renamed
        expect(db).to(haveIndex("names_of_people", on: "people", columns: ["name"]))
    }
}
