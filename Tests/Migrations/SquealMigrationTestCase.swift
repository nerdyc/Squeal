import Foundation
import XCTest
import Nimble
@testable import Squeal

class SquealMigrationTestCase : XCTestCase {
    
    override func setUp() {
        self.continueAfterFailure = false
        super.setUp()
    }
    
    func newDatabaseAtVersion(_ version:Int, ofSchema schema:Schema, file:StaticString = #file, line:UInt = #line) -> Database {
        let db = Database()
        migrate(db, schema: schema, version: version, file: file, line:line)
        return db
    }
    
    func migrate(_ db:Database, schema:Schema, options:MigrationOptions = [], version:Int? = nil, file:StaticString = #file, line:UInt = #line) {
        do {
            _ = try schema.migrate(db, toVersion: version, options:options)
        } catch {
            XCTFail("Failed to migrate database: \(error)", file: file, line:line)
        }
        
        let expectedVersion = Int(version ?? schema.latestVersion?.number ?? 0)
        expect(try db.queryUserVersionNumber()) == expectedVersion
    }
    
    func defineTable(_ name:String, block:(TableBuilder)->Void) -> Schema {
        return Schema(identifier:#function) { s in
            s.version(1) { v1 in
                v1.createTable(name, block:block)
            }
        }
        
    }
    
}


func tableInfoWithName(_ name:String, inDatabase db:Database, file:StaticString = #file, line:UInt = #line) -> TableInfo? {
    do {
        return try db.tableInfoForTableNamed(name)
    } catch {
        XCTFail("Failed to get info for table '\(name)': \(error)", file: file, line:line)
        return nil
    }
}
