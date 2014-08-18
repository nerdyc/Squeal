import Quick
import Nimble
import Squeal

class DatabaseContentSpec: QuickSpec {
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
        // MARK:- Insert
        
        describe(".insertRow(tableName:columns:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertRow("contacts",
                                            columns:["name"],
                                            values:["Amelia"],
                                            error:&error)
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))
                expect(error).to(beNil())
                
                let query = database.query("SELECT * FROM contacts")
                expect(query.next()).to(beTruthy())
                expect(query.intValue("contactId")).to(equal(1))
                expect(query.stringValue("name")).to(equal("Amelia"))

                expect(query.next()).to(beFalsy())
            }
            
        }
        
        describe(".insertRow(tableName:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertRow("contacts", values:["name":"Amelia"], error:&error)
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))
                expect(error).to(beNil())
                
                let query = database.query("SELECT * FROM contacts")
                expect(query.next()).to(beTruthy())
                expect(query.intValue("contactId")).to(equal(1))
                expect(query.stringValue("name")).to(equal("Amelia"))
                
                expect(query.next()).to(beFalsy())
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Select
        
        describe(".selectFrom(from:columns:whereExpr:groupBy:having:orderBy:limit:offset:parameters:error:") {
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.insert("contacts", row:["name": "Amelia"])
                database.insert("contacts", row:["name": "Brian"])
                database.insert("contacts", row:["name": "Cara"])
            }
            
            context("when the statement is valid") {
                
                beforeEach {
                    statement = database.selectFrom("contacts",
                                                    whereExpr:  "contactId > ?",
                                                    orderBy:    "name",
                                                    parameters: [1],
                                                    error:      &error)
                }
                
                it("returns the statement") {
                    expect(statement).notTo(beNil())
                    expect(error).to(beNil())
                    if statement != nil {
                        var names = statement.collect { $0.stringValue("name") }
                        expect(names.count).to(equal(2))
                        expect(names[0]).to(equal("Brian"))
                        expect(names[1]).to(equal("Cara"))
                    }
                }
                
            }
            
            context("when the statement is invalid") {
                
                beforeEach {
                    statement = database.selectFrom("contacts",
                                                    whereExpr:  "sdfsdfsf IS NULL",
                                                    error:      &error)
                }
                
                it("provides an error") {
                    expect(statement).to(beNil())
                    expect(error).notTo(beNil())
                }
                
            }
            
        }
        
    }
}
