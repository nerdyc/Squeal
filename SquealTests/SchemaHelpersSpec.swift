import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class DatabaseSchemaSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var error : NSError?
        
        beforeEach {
            database = Database.openTemporaryDatabase()
        }
        
        afterEach {
            database = nil
            error = nil
        }
        
        // =============================================================================================================
        // MARK:- Schema & Table Info
        
        describe(".schema") {
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
                database.executeOrFail("CREATE INDEX contacts_name ON contacts (firstName, lastName)")
                
                database.executeOrFail("CREATE TABLE emailAddresses (emailId INTEGER PRIMARY KEY, address TEXT UNIQUE NOT NULL, contactId INTEGER NOT NULL)")
                database.executeOrFail("CREATE INDEX emailAddresses_contactId ON emailAddresses (contactId)")
                
                database.executeOrFail("CREATE TABLE phoneNumbers (phoneNumberId INTEGER PRIMARY KEY, number TEXT NOT NULL, contactId INTEGER NOT NULL)")

            }
            
            it("returns a Schema object describing the database schema") {
                expect(database.schema.tableNames).to(equal(["contacts", "emailAddresses", "phoneNumbers"]))
                expect(database.schema.indexNames).to(equal(["contacts_name",
                                                             "sqlite_autoindex_emailAddresses_1", // UNIQUE column 1
                                                             "emailAddresses_contactId"]))
                
                expect(database.schema.namesOfIndexesOnTable("emailAddresses")).to(equal(["sqlite_autoindex_emailAddresses_1",
                                                                                          "emailAddresses_contactId"]))
                expect(database.schema.namesOfIndexesOnTable("contacts")).to(equal(["contacts_name"]))
                expect(database.schema.namesOfIndexesOnTable("phoneNumbers")).to(equal([]));
            }
            
        }
        
        describe(".tableInfoForTableNamed(name:error:)") {
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
            }
            
            it("returns a TableInfo object describing the table") {
                let tableInfo = database.tableInfoForTableNamed("contacts")
                expect(tableInfo).notTo(beNil())
                if tableInfo != nil {
                    expect(tableInfo!.name).to(equal("contacts"))
                    expect(tableInfo!.columns.count).to(equal(3))
                    expect(tableInfo!.columnNames).to(equal(["contactId", "firstName", "lastName"]))
                }
            }
            
        }
        
        describe(".queryUserVersionNumber(error:)") {
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
            }
            
            it("is 0 when database is created") {
                expect(database.queryUserVersionNumber()).to(equal(0))
            }
            
            it("is non-zero when set by the developer") {
                var result = database.updateUserVersionNumber(123, error:&error)
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                
                expect(database.queryUserVersionNumber()).to(equal(123))
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Create Table
        
        describe(".createTable(name:columns:error:)") {
            
            var result : Bool = false
            
            context("when the table definition is valid") {
                
                beforeEach {
                    result = database.createTable("contacts",
                                                  definitions:[ "contactId INTEGER PRIMARY KEY",
                                                                "firstName TEXT",
                                                                "lastName  TEXT" ],
                                                  error:&error)
                }
                
                it("creates the table") {
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                    
                    expect(database.schema.tableNames).to(equal(["contacts"]))
                    expect(database.tableInfoForTableNamed("contacts")!.columnNames).to(equal(["contactId", "firstName", "lastName"]))
                }
                
            }

            context("when the table already exists") {
                
                beforeEach {
                    database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                }
                
                it("returns false and provides an error by default") {
                    result = database.createTable("contacts",
                                                  definitions:[ "contactId INTEGER PRIMARY KEY" ],
                                                  error:&error)
                    
                    expect(result).to(beFalsy())
                    expect(error).notTo(beNil())
                }

                it("doesn't error if ifNotExists is true") {
                    result = database.createTable("contacts",
                                                  definitions:[ "contactId INTEGER PRIMARY KEY" ],
                                                  ifNotExists:true,
                                                  error:&error)
                    
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                }

            }
            
            context("when the table definition is invalid") {
                
                beforeEach {
                    result = database.createTable("contacts",
                                                  definitions:[ "contactId  INTEGER DEFAULT" ],
                                                  error:&error)
                }
                
                it("returns false and provides an error") {
                    expect(result).to(beFalsy())
                    expect(error).notTo(beNil())
                }
                
            }
            
        }

        // =============================================================================================================
        // MARK:- Drop Table
        
        describe(".dropTable(name:error:)") {
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                database.executeOrFail("CREATE TABLE emails (emailId INTEGER PRIMARY KEY)")
            }
            
            it("drops the table from the database") {
                var result = database.dropTable("contacts", error: &error)

                expect(result).to(beTruthy())
                expect(error).to(beNil())
                expect(database.schema.tableNames).to(equal(["emails"]))
            }
            
            it("provides an error if the table doesn't exist") {
                var result = database.dropTable("phones", error: &error)
                
                expect(result).to(beFalsy())
                expect(error).notTo(beNil())
            }
            
            it("doesn't error if the table doesn't exist and ifExists is true") {
                var result = database.dropTable("phones", ifExists:true, error: &error)
                
                expect(result).to(beTruthy())
                expect(error).to(beNil())
            }

        }
        
        // =================================================================================================================
        // MARK:- Rename Table
        
        describe(".renameTable(tableName:to:error:)") {
            var result : Bool = false
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                result = database.renameTable("contacts", to:"people", error:&error)
            }
            
            it("renames the table") {
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                
                expect(database.schema.tableNames).to(equal(["people"]))
            }
        }

        describe(".addColumnToTable(tableName:column:error:") {
            var result : Bool = false
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                result = database.addColumnToTable("contacts", column:"name TEXT", error:&error)
            }
            
            it("adds a column to a table") {
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                
                expect(database.tableInfoForTableNamed("contacts")?.columnNames).to(equal(["contactId", "name"]))
            }
        }

        // =================================================================================================================
        // MARK:- Create Index
        
        describe(".createIndex(name:tableName:columns:error:)") {
            var result : Bool = false
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER, name TEXT)")
            }
            
            context("when the index doesn't exist") {
                beforeEach {
                    result = database.createIndex("contacts_name",
                                                  tableName:    "contacts",
                                                  columns:      ["name"],
                                                  error:        &error)
                }
            
                it("creates an index over the given columns") {
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                    
                    expect(database.schema.indexesOnTable("contacts").map { $0.name }).to(equal(["contacts_name"]))
                }
            }
            
            context("when the index already exists") {
                
                beforeEach {
                    database.executeOrFail("CREATE INDEX contacts_name ON contacts (name)")
                }
                
                it("returns an error") {
                    result = database.createIndex("contacts_name",
                                                  tableName:    "contacts",
                                                  columns:      ["name"],
                                                  error:        &error)
                    
                    expect(result).to(beFalsy())
                    expect(error).notTo(beNil())
                }

                it("doesn't return an error if ifNotExists is true") {
                    result = database.createIndex("contacts_name",
                                                  tableName:    "contacts",
                                                  columns:      ["name"],
                                                  ifNotExists:  true,
                                                  error:        &error)
                    
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                }

            }
            
        }
        
        describe(".dropIndex(name:ifExists:error:)") {
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.executeOrFail("CREATE INDEX contacts_name ON contacts (name)")
            }
            
            it("drops the index from the database") {
                var result = database.dropIndex("contacts_name", error: &error)
                
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                expect(database.schema.indexNames).to(equal([]))
            }
            
            it("provides an error if the index doesn't exist") {
                var result = database.dropIndex("contacts_not_an_index", error: &error)
                
                expect(result).to(beFalsy())
                expect(error).notTo(beNil())
            }
            
            it("doesn't error if the index doesn't exist and ifExists is true") {
                var result = database.dropIndex("contacts_not_an_index", ifExists:true, error: &error)
                
                expect(result).to(beTruthy())
                expect(error).to(beNil())
            }
            
        }
        
    }
}
