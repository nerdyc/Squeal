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
        
        describe(".insertInto(tableName:columns:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertInto("contacts",
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
        
        describe(".insertInto(tableName:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertInto("contacts", values:["name":"Amelia"], error:&error)
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
            
            var values : [String]?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.insert("contacts", row:["name": "Amelia"])
                database.insert("contacts", row:["name": "Brian"])
                database.insert("contacts", row:["name": "Cara"])
            }
            
            afterEach { values = nil }
            
            context("when the statement is valid") {
                
                
                beforeEach {
                    values = database.selectFrom("contacts", error:&error) { $0.stringValue("name")! }
                }
                
                it("returns the collected values") {
                    expect(values).to(equal(["Amelia", "Brian", "Cara"]))
                    expect(error).to(beNil())
                }
                
            }

            
            context("when the statement has a where clause") {
                
                beforeEach {
                    values = database.selectFrom("contacts",
                                                 whereExpr:  "contactId > ?",
                                                 orderBy:    "name",
                                                 parameters: [1],
                                                 error:      &error) { $0.stringValue("name")! }
                }
                
                it("returns the collected values") {
                    expect(values).to(equal(["Brian", "Cara"]))
                    expect(error).to(beNil())
                }
                
            }
            
            context("when the statement is invalid") {
                
                beforeEach {
                    values = database.selectFrom("contacts",
                                                 whereExpr:   "sdfsdfsf IS NULL",
                                                 error:       &error)  { $0.stringValue("name")! }
                }
                
                it("provides an error") {
                    expect(values).to(beNil())
                    expect(error).notTo(beNil())
                }
                
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Update
        
        describe(".update(tableName:set:whereExpr:parameters:error:)") {
            
            var result : Int?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.insert("contacts", row:["name": "Amelia"])
                database.insert("contacts", row:["name": "Brian"])
                database.insert("contacts", row:["name": "Cara"])

                result = database.update("contacts",
                                         set:       ["name":"Bobby"],
                                         whereExpr: "name IS ?",
                                         parameters:["Brian"],
                                         error:     &error)
            }
            
            it("updates the values in the database") {
                var values = database.selectFrom("contacts",
                                                 columns:  ["name"],
                                                 error:&error) { $0.stringValue("name")! }
                
                expect(result).to(equal(1))
                expect(values).to(equal(["Amelia", "Bobby", "Cara"]))
                expect(error).to(beNil())
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Delete
        
        describe(".deleteFrom(tableName:whereExpr:parameters:error:)") {
            
            var result : Int?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.insert("contacts", row:["name": "Amelia"])
                database.insert("contacts", row:["name": "Brian"])
                database.insert("contacts", row:["name": "Cara"])
                
                result = database.deleteFrom("contacts",
                                             whereExpr: "name IS ?",
                                             parameters:["Brian"],
                                             error:     &error)
            }
            
            it("deletes the matching values in the database") {
                var values = database.selectFrom("contacts",
                                                 columns:  ["name"],
                                                 error:&error) { $0.stringValue("name")! }
                
                expect(result).to(equal(1))
                expect(values).to(equal(["Amelia", "Cara"]))
                expect(error).to(beNil())
            }
            
        }
        
    }
}
