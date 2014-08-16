import Quick
import Nimble
import sqlite3
import Squeal
import Foundation

class DatabaseSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var tempPath : String!
        
        beforeEach {
            tempPath = createTemporaryDirectory()
            database = Database(path:tempPath + "/Squeal")
        }

        // =============================================================================================================
        // MARK:- Initialization
        
        describe("newInMemoryDatabase()") {
            
            it("returns an in-memory database") {
                var inMemoryDB = Database.newInMemoryDatabase()
                expect(inMemoryDB.isInMemoryDatabase).to(beTruthy())
                expect(inMemoryDB.isTemporaryDatabase).to(beFalsy())
                expect(inMemoryDB.isPersistentDatabase).to(beFalsy())
            }
            
        }
        
        describe("newTemporaryDatabase()") {
            
            it("returns a temporary database") {
                var temporaryDB = Database.newTemporaryDatabase()
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
        // MARK:- Open
        
        describe("open()") {
            
            context("when the database doesn't exist") {
                
                beforeEach {
                    var error : NSError?
                    if !database.open(&error) {
                        NSException(name: NSInternalInconsistencyException,
                                    reason: "Unable to open database \(error)",
                                    userInfo: nil)
                    }
                }
                
                it("creates the database") {
                    expect(database.isOpen).to(beTruthy())
                    expect(NSFileManager.defaultManager().fileExistsAtPath(database.path)).to(beTruthy())
                }
                
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Close
        
        describe("close()") {
            
            var result: Bool = false
            var error: NSError?
            var statement: Statement?
            
            beforeEach {
                database.open()
                database.execute("CREATE TABLE people (id PRIMARY KEY, name TEXT)")
                database.execute("INSERT INTO people(name) VALUES ('A'), ('B'), ('C')")
                statement = database.query("SELECT id,name FROM people")
                statement!.next(&error)
                
                result = database.close(&error)
            }
            
            it("closes the database and any open statements") {
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                
                expect(statement!.isOpen).to(beFalsy())
                expect(statement!.columnCount).to(equal(0))
                expect(statement!.intValueAtIndex(0)).to(beNil())
                expect(statement!.stringValueAtIndex(1)).to(beNil())
            }
            
        }
        
        // =================================================================================================================
        // MARK:- Statements
        
        describe("prepareStatement(sql:error:)") {
            
            var error: NSError?
            var statement: Statement?
            
            beforeEach {
                database.open()
            }
            
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