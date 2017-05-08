import XCTest
import Nimble
@testable import Squeal

class CreateIndexTests: SquealMigrationTestCase {
    
    func test_createIndex() {
        // SETUP: A table and an index
        let schema = Schema { s in
            s.version(1) { v in
                v.createTable("people") { people in
                    people.primaryKey("id")
                    people.column("name", .Text, "NOT NULL")
                }
                
                v.createIndex("people_names", on:"people", columns:["name"], where:"name != ''", unique:true)
            }
        }
        
        // VERIFY: Index exists in the schema
        let schemaIndex = schema.latestVersion?.indexNamed("people_names")
        expect(schemaIndex).notTo(beNil())
        expect(schemaIndex?.name) == "people_names"
        expect(schemaIndex?.tableName) == "people"
        expect(schemaIndex?.columns) == [ "name" ]
        expect(schemaIndex?.unique) == true
        expect(schemaIndex?.whereClause) == "name != ''"
        
        // VERIFY: Migration succeeds
        let db = Database()
        expect {
            try schema.migrate(db)
        }.notTo(throwError())
        
        // VERIFY: Index is created correctly
        let dbIndex = try! db.tableInfoForTableNamed("people")?.indexNamed("people_names")
        expect(dbIndex).notTo(beNil())
        expect(dbIndex?.name) == "people_names"
        expect(dbIndex?.columnNames) == [ "name" ]
        expect(dbIndex?.isUnique) == true
        expect(dbIndex?.isPartial) == true
    }
    
}
