import Foundation
import Quick
import Nimble
import Squeal
import Clibsqlite3

class DatabaseSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var tempPath : String!
        
        beforeEach {
            tempPath = try! Database.createTemporaryDirectory()
            database = try! Database(path:tempPath + "/Squeal")
        }
        
        afterEach {
            database = nil
            tempPath = nil
        }

        // =============================================================================================================
        // MARK:- Initialization
        
        describe("newInMemoryDatabase()") {
            
            it("returns an in-memory database") {
                let inMemoryDB = Database.newInMemoryDatabase()
                
                expect(inMemoryDB.isInMemoryDatabase).to(beTruthy())
                expect(inMemoryDB.isTemporaryDatabase).to(beFalsy())
                expect(inMemoryDB.isPersistentDatabase).to(beFalsy())
            }
            
        }
        
        describe("newTemporaryDatabase(error:)") {
            
            it("returns a temporary database") {
                let temporaryDB = Database.newTemporaryDatabase()
                
                expect(temporaryDB.isInMemoryDatabase).to(beFalsy())
                expect(temporaryDB.isTemporaryDatabase).to(beTruthy())
                expect(temporaryDB.isPersistentDatabase).to(beFalsy())
            }
            
        }

        describe("isPersistentDatabase") {
            it("returns true for non-temporary, on-disk databases") {
                expect(database.isInMemoryDatabase).to(beFalsy())
                expect(database.isTemporaryDatabase).to(beFalsy())
                expect(database.isPersistentDatabase).to(beTruthy())
            }
        }
        
        // =============================================================================================================
        // MARK:- Statements
        
        describe("prepareStatement(sql:error:)") {
            
            it("returns a Statement when the sql is valid") {
                do {
                    _ = try database.prepareStatement("CREATE TABLE people (personId INTEGER PRIMARY KEY)")
                } catch let e {
                    fail("Unexpected error thrown when preparing statement: \(e)")
                }
            }
            
            it("provides an error when the sql is invalid") {
                do {
                    _ = try database.prepareStatement("CREATE TABLE people (personId INTE")
                    fail("Expected an error to be thrown")
                } catch {
                    
                }
            }
            
        }
        
    }
}
