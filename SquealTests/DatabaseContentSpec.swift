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
        
        describe(".select(from:columns:whereExpr:groupBy:having:orderBy:limit:offset:parameters:error:") {
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.insert("contacts", row:["name": "Amelia"])
                database.insert("contacts", row:["name": "Brian"])
                database.insert("contacts", row:["name": "Cara"])
            }
            
            context("when the statement is valid") {
                
                var values : [String?]?
                
                beforeEach {
                    values = database.selectFrom("contacts", collector:{ $0.stringValue("name") })
                }
                
                it("returns the collected values") {
                    expect(values).notTo(beNil())
                    expect(error).to(beNil())
                    if values != nil {
                        expect(values!.count).to(equal(3))
                        expect(values![0]).to(equal("Amelia"))
                        expect(values![1]).to(equal("Brian"))
                        expect(values![2]).to(equal("Cara"))
                    }
                }
                
            }

            
            context("when the statement has a where clause") {
                
                var values : [String?]?
                
                beforeEach {
                    values = database.selectFrom("contacts",
                                                 whereExpr:  "contactId > ?",
                                                 orderBy:    "name",
                                                 parameters: [1],
                                                 error:      &error) { $0.stringValue("name") }
                }
                
                it("returns the collected values") {
                    expect(values).notTo(beNil())
                    expect(error).to(beNil())
                    if values != nil {
                        expect(values!.count).to(equal(2))
                        expect(values![0]).to(equal("Brian"))
                        expect(values![1]).to(equal("Cara"))
                    }
                }
                
            }
            
            context("when the statement is invalid") {
                
                var values : [String?]?
                
                beforeEach {
                    values = database.selectFrom("contacts",
                                                 whereExpr:   "sdfsdfsf IS NULL",
                                                 error:       &error)  { $0.stringValue("name") }
                }
                
                it("provides an error") {
                    expect(values).to(beNil())
                    expect(error).notTo(beNil())
                }
                
            }
            
        }
        
    }
}
