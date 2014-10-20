import Foundation
import Quick
import Nimble
import Squeal
import SquealSpecHelpers

#if os(iOS)
    #if arch(i386) || arch(x86_64)
        import sqlite3_ios_simulator
    #else
        import sqlite3_ios
    #endif
#else
import sqlite3_osx
#endif

class DatabaseSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var tempPath : String!
        var error : NSError?
        
        beforeEach {
            tempPath = Database.createTemporaryDirectory()
            database = Database(path:tempPath + "/Squeal", error:&error)
            expect(database).notTo(beNil())
            expect(error).to(beNil())
        }
        
        afterEach {
            database = nil
            tempPath = nil
            error = nil
        }

        // =============================================================================================================
        // MARK:- Initialization
        
        describe("newInMemoryDatabase(error:)") {
            
            it("returns an in-memory database") {
                var inMemoryDB = Database.newInMemoryDatabase(error:&error)
                expect(inMemoryDB).notTo(beNil())
                expect(error).to(beNil())
                
                expect(inMemoryDB!.isInMemoryDatabase).to(beTruthy())
                expect(inMemoryDB!.isTemporaryDatabase).to(beFalsy())
                expect(inMemoryDB!.isPersistentDatabase).to(beFalsy())
            }
            
        }
        
        describe("newTemporaryDatabase(error:)") {
            
            it("returns a temporary database") {
                var temporaryDB = Database.newTemporaryDatabase(error:&error)
                expect(temporaryDB).notTo(beNil())
                expect(error).to(beNil())
                
                expect(temporaryDB!.isInMemoryDatabase).to(beFalsy())
                expect(temporaryDB!.isTemporaryDatabase).to(beTruthy())
                expect(temporaryDB!.isPersistentDatabase).to(beFalsy())
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
            
            var statement: Statement?
            
            it("returns a Statement when the sql is valid") {
                statement = database.prepareStatement("CREATE TABLE people (personId INTEGER PRIMARY KEY)",
                                                      error: &error)
                expect(statement).notTo(beNil())
                expect(error).to(beNil())
            }
            
            it("provides an error when the sql is invalid") {
                statement = database.prepareStatement("CREATE TABLE people (personId INTE",
                    error: &error)
                expect(statement).to(beNil())
                expect(error).notTo(beNil())
            }
            
        }
        
    }
}