import Quick
import Nimble
import Squeal

class DatabaseSchemaSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var statement : Statement!
        var error : NSError?
        
        beforeEach {
            database = Database.newTemporaryDatabase()
            database.open()
        }
        
        afterEach {
            if (statement != nil && statement.isOpen) {
                statement.close()
            }
            statement = nil
            
            if database.isOpen {
                database.close(nil)
            }
            database = nil
            
            error = nil
        }
        
        // =============================================================================================================
        // MARK:- Schema & Table Info
        
        describe(".schema") {
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
                database.execute("CREATE INDEX contacts_name ON contacts (firstName, lastName)")
                
                database.execute("CREATE TABLE emailAddresses (emailId INTEGER PRIMARY KEY, address TEXT UNIQUE NOT NULL, contactId INTEGER NOT NULL)")
                database.execute("CREATE INDEX emailAddresses_contactId ON emailAddresses (contactId)")
                
                database.execute("CREATE TABLE phoneNumbers (phoneNumberId INTEGER PRIMARY KEY, number TEXT NOT NULL, contactId INTEGER NOT NULL)")

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
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
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
                    database.createTable("contacts",
                                         definitions:[ "contactId  INTEGER PRIMARY KEY" ],
                                         error:&error)
                    
                    result = database.createTable("contacts",
                                                  definitions:[ "contactId  INTEGER PRIMARY KEY" ],
                                                  error:&error)
                }
                
                it("returns false and provides an error") {
                    expect(result).to(beFalsy())
                    expect(error).notTo(beNil())
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

        describe(".createTableIfNotExists(name:columns:error:)") {
            
            var result : Bool = false
            
            context("when the table definition is valid") {
                beforeEach {
                    result = database.createTableIfNotExists("contacts",
                                                             definitions:[ "contactId INTEGER PRIMARY KEY" ],
                                                             error:&error)
                }
                
                it("creates the table") {
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                    expect(database.schema.tableNames).to(equal(["contacts"]))
                }
            }
            
            context("when the table already exists") {
                
                beforeEach {
                    database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                    database.createTableIfNotExists("contacts",
                                                    definitions:[ "contactId INTEGER PRIMARY KEY" ],
                                                    error:&error)
                }
                
                it("doesn't create an error") {
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                }
            }
            
        }

        // =================================================================================================================
        // MARK:- Drop Table
        
        describe(".dropTable(name:error:)") {
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                database.execute("CREATE TABLE emails (emailId INTEGER PRIMARY KEY)")
            }
            
            it("drops the table from the database") {
                var result = database.dropTableIfExists("contacts", error: &error)

                expect(result).to(beTruthy())
                expect(error).to(beNil())
                expect(database.schema.tableNames).to(equal(["emails"]))
            }
            
            it("provides an error if the table doesn't exist") {
                var result = database.dropTable("phones", error: &error)
                
                expect(result).to(beFalsy())
                expect(error).notTo(beNil())
            }
        }

        describe(".dropTableIfExists(name:error:)") {
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                database.execute("CREATE TABLE emails (emailId INTEGER PRIMARY KEY)")
            }
            
            it("drops the table from the database") {
                var result = database.dropTableIfExists("contacts", error: &error)
                
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                expect(database.schema.tableNames).to(equal(["emails"]))
            }
            
            it("doesn't provide an error if the table doesn't exist") {
                var result = database.dropTableIfExists("phones", error: &error)
                
                expect(result).to(beTruthy())
                expect(error).to(beNil())
            }
        }

        // =================================================================================================================
        // MARK:- Rename Table
        
        describe(".renameTable(tableName:to:") {
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                database.renameTable("contacts", to:"people")
            }
            
            it("renames the table") {
                expect(database.schema.tableNames).to(equal(["people"]))
            }
        }

        describe(".addColumnToTable(tableName:column:") {
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
            }
            
            it("adds a column to a table") {
                var result = database.addColumnToTable("contacts", column:"name TEXT", error:&error)
                
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                expect(database.tableInfoForTableNamed("contacts")?.columnNames).to(equal(["contactId", "name"]))
            }
        }

    }
}
