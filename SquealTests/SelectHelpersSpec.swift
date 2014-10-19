import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class SelectHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var error : NSError?
        
        beforeEach {
            database = Database.openTemporaryDatabase()
            
            database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT, initials TEXT)")
            database.insert("contacts", row:["name": "Amelia", "initials": "A"])
            database.insert("contacts", row:["name": "Brian",  "initials": NSNull()])
            database.insert("contacts", row:["name": "Cara",   "initials": "C"])
        }
        
        afterEach {
            database = nil
            error = nil
        }
        
        // =============================================================================================================
        // MARK:- Select
        
        describe(".selectFrom(from:columns:whereExpr:groupBy:having:orderBy:limit:offset:parameters:error:") {
            
            var values : [String]?
            
            afterEach { values = nil }
            
            context("when the statement is valid") {
                
                beforeEach {
                    values = map(database.selectFrom("contacts")) { $0!["name"] as String }
                }
                
                it("returns the collected values") {
                    expect(values?[0]).to(equal("Amelia"))
                    expect(values?[1]).to(equal("Brian"))
                    expect(values?[2]).to(equal("Cara"))
                    expect(error).to(beNil())
                }
                
            }

            
            context("when the statement has a where clause") {
                
                beforeEach {
                    values = map(database.selectFrom("contacts",
                                                     whereExpr:  "contactId > ?",
                                                     orderBy:    "name",
                                                     parameters: [1])) { $0!["name"] as String }
                }
                
                it("returns the collected values") {
                    expect(values?[0]).to(equal("Brian"))
                    expect(values?[1]).to(equal("Cara"))
                    expect(error).to(beNil())
                }
                
            }
            
            context("when the statement is invalid") {
                
                beforeEach {
                    for s in database.selectFrom("contacts", whereExpr: "sdfsdfsf IS NULL", error:&error) {
                        // skip
                    }
                }
                
                it("provides an error") {
                    expect(error).notTo(beNil())
                }
                
            }
            
        }
        
        describe(".selectRowIdsFrom(tableName:whereExpr:orderBy:limit:offset:parameters:error:") {
            
            var rowIds : [RowId]?
            
            beforeEach {
                rowIds = database.selectRowIdsFrom("contacts",
                                                   whereExpr:   "name > ?",
                                                   orderBy:     "name DESC",
                                                   parameters:  ["B"],
                                                   error:       &error)
            }
            
            afterEach {
                rowIds = nil
            }
            
            it("returns the IDs of the selected rows") {
                expect(rowIds).to(equal([3, 2]))
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Count

        describe(".countFrom(from:columns:whereExpr:parameters:error:") {
            
            var count : Int64?
            
            context("when no whereExpr is provided") {
                beforeEach {
                    count = database.countFrom("contacts", error:&error)
                }
                
                it("counts all rows") {
                    expect(count).to(equal(3))
                    expect(error).to(beNil())
                }
            }
            
            context("when columns are provided") {
                beforeEach {
                    count = database.countFrom("contacts", columns:["initials"], error:&error)
                }
                
                it("counts all rows with non-null values") {
                    expect(count).to(equal(2))
                    expect(error).to(beNil())
                }
            }
            
            context("when a where clause is provided") {
                beforeEach {
                    count = database.countFrom("contacts", whereExpr:"contactId > ?", parameters:[2], error:&error)
                }
                
                it("counts all rows matching the expression") {
                    expect(count).to(equal(1))
                    expect(error).to(beNil())
                }
            }
            
        }
        
    }
}
