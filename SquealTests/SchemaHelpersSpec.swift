import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class DatabaseSchemaSpec: QuickSpec {
    override func spec() {
        
        var database: Database!
        
        beforeEach {
            database = Database()
        }
        
        afterEach {
            database = nil
        }
        
        // =============================================================================================================
        // MARK:- Schema & Table Info
        
        describe(".schema") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
                try! database.execute("CREATE INDEX contacts_name ON contacts (firstName, lastName)")
                
                try! database.execute("CREATE TABLE emailAddresses (emailId INTEGER PRIMARY KEY, address TEXT UNIQUE NOT NULL, contactId INTEGER NOT NULL)")
                try! database.execute("CREATE INDEX emailAddresses_contactId ON emailAddresses (contactId)")
                
                try! database.execute("CREATE TABLE phoneNumbers (phoneNumberId INTEGER PRIMARY KEY, number TEXT NOT NULL, contactId INTEGER NOT NULL)")
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
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, firstName TEXT, lastName TEXT)")
            }
            
            it("returns a TableInfo object describing the table") {
                let tableInfo = try! database.tableInfoForTableNamed("contacts")
                expect(tableInfo?.name).to(equal("contacts"))
                expect(tableInfo?.columns.count).to(equal(3))
                expect(tableInfo?.columnNames).to(equal(["contactId", "firstName", "lastName"]))
                
                expect(tableInfo?.indexes.count) == 0
                expect(tableInfo?.indexNames) == []

            }
            
            context("when an index exists") {
                
                beforeEach {
                    try! database.execute("CREATE INDEX contacts_lastName ON contacts (lastName)")
                    try! database.execute("CREATE UNIQUE INDEX contacts_fullName ON contacts (firstName, lastName) WHERE firstName IS NOT NULL AND lastName IS NOT NULL")
                }
                
                it("includes info about the indexes") {
                    var tableInfo:TableInfo?
                    expect {
                        tableInfo = try database.tableInfoForTableNamed("contacts")
                    }.notTo(throwError())
                    
                    expect(tableInfo?.indexNames.sort()) == [ "contacts_fullName", "contacts_lastName" ]
                    
                    expect(tableInfo?.indexNamed("contacts_lastName")?.columnNames) == [ "lastName" ]
                    expect(tableInfo?.indexNamed("contacts_lastName")?.isUnique) == false
                    expect(tableInfo?.indexNamed("contacts_lastName")?.isPartial) == false
                    
                    expect(tableInfo?.indexNamed("contacts_fullName")?.columnNames) == [ "firstName", "lastName" ]
                    expect(tableInfo?.indexNamed("contacts_fullName")?.isUnique) == true
                    expect(tableInfo?.indexNamed("contacts_fullName")?.isPartial) == true
                }
                
            }
            
        }
        
        describe(".queryUserVersionNumber()") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
            }
            
            it("is 0 when database is created") {
                expect(try! database.queryUserVersionNumber()).to(equal(0))
            }
            
            it("is non-zero when set by the developer") {
                try! database.updateUserVersionNumber(123)
                expect(try! database.queryUserVersionNumber()).to(equal(123))
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Create Table
        
        describe(".createTable(name:columns:error:)") {
            
            context("when the table definition is valid") {
                
                beforeEach {
                    try! database.createTable("contacts",
                                              definitions:[ "contactId INTEGER PRIMARY KEY",
                                                            "firstName TEXT",
                                                            "lastName  TEXT" ])
                }
                
                it("creates the table") {
                    expect(database.schema.tableNames).to(equal(["contacts"]))
                    expect(try! database.tableInfoForTableNamed("contacts")?.columnNames).to(equal(["contactId", "firstName", "lastName"]))
                }
                
            }

            context("when the table already exists") {
                
                beforeEach {
                    try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                }
                
                it("throws an error") {
                    do {
                        try database.createTable("contacts",
                                                 definitions:[ "contactId INTEGER PRIMARY KEY" ])
                        fail("Expected creating a second table with the same name to throw an error")
                    } catch {
                        // yay, an error!
                    }
                }

                it("doesn't error if ifNotExists is true") {
                    do {
                        try database.createTable("contacts",
                                                  definitions:[ "contactId INTEGER PRIMARY KEY" ],
                                                  ifNotExists:true)
                    } catch let e {
                        fail("Error thrown even though 'IF NOT EXISTS' specified: \(e)")
                    }
                }

            }
            
            context("when the table definition is invalid") {
                
                it("throws an error") {
                    do {
                        try database.createTable("contacts",
                                                 definitions:[ "contactId  INTEGER DEFAULT" ])
                        fail("Expected creating a second table with the same name to throw an error")
                    } catch {
                        
                    }
                }
                
            }
            
        }

        // =============================================================================================================
        // MARK:- Drop Table
        
        describe(".dropTable(name:error:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                try! database.execute("CREATE TABLE emails (emailId INTEGER PRIMARY KEY)")
            }
            
            it("drops the table from the database") {
                try! database.dropTable("contacts")
                expect(database.schema.tableNames).to(equal(["emails"]))
            }
            
            it("throws an error if the table doesn't exist") {
                do {
                    try database.dropTable("phones")
                    fail("Expected dropping an unknown table to throw an error")
                } catch {
                    
                }
            }
            
            it("doesn't error if the table doesn't exist and ifExists is true") {
                do {
                    try database.dropTable("phones", ifExists:true)
                } catch let e {
                    fail("Expected no error to be thrown when ifExists is true: \(e)")
                }
            }

        }
        
        // =================================================================================================================
        // MARK:- Rename Table
        
        describe(".renameTable(tableName:to:error:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                try! database.renameTable("contacts", to:"people")
            }
            
            it("renames the table") {
                expect(database.schema.tableNames).to(equal(["people"]))
            }
        }

        describe(".addColumnToTable(tableName:column:error:") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY)")
                try! database.addColumnToTable("contacts", column:"name TEXT")
            }
            
            it("adds a column to a table") {
                expect(try! database.tableInfoForTableNamed("contacts")?.columnNames).to(equal(["contactId", "name"]))
            }
        }

        // =================================================================================================================
        // MARK:- Create Index
        
        describe(".createIndex(name:tableName:columns:error:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER, name TEXT)")
            }
            
            context("when the index doesn't exist") {
                beforeEach {
                    try! database.createIndex("contacts_name",
                                              tableName:    "contacts",
                                              columns:      ["name"])
                }
            
                it("creates an index over the given columns") {
                    expect(database.schema.indexesOnTable("contacts").map { $0.name }).to(equal(["contacts_name"]))
                }
            }
            
            context("when the index already exists") {
                
                beforeEach {
                    try! database.execute("CREATE INDEX contacts_name ON contacts (name)")
                }
                
                it("returns an error") {
                    do {
                        try database.createIndex("contacts_name",
                                                 tableName:    "contacts",
                                                 columns:      ["name"])
                        fail("Expected error to be thrown when index already exists")
                    } catch {
                        
                    }
                }

                it("doesn't return an error if ifNotExists is true") {
                    do {
                        try database.createIndex("contacts_name",
                                                 tableName:    "contacts",
                                                 columns:      ["name"],
                                                 ifNotExists:  true)
                    } catch let e {
                        fail("Didn't expect error to be thrown: \(e)")
                    }
                }

            }
            
        }
        
        describe(".dropIndex(name:ifExists:error:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                try! database.execute("CREATE INDEX contacts_name ON contacts (name)")
            }
            
            it("drops the index from the database") {
                try! database.dropIndex("contacts_name")
                expect(database.schema.indexNames).to(equal([]))
            }
            
            it("provides an error if the index doesn't exist") {
                do {
                    try database.dropIndex("contacts_not_an_index")
                    fail("Expected error to be thrown!")
                } catch {
                    
                }
            }
            
            it("doesn't error if the index doesn't exist and ifExists is true") {
                do  {
                    try database.dropIndex("contacts_not_an_index", ifExists:true)
                } catch {
                    fail("Error shouldn't be thrown!")
                }
            }
            
        }
        
    }
}
