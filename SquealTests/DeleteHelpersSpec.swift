import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class DeleteHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var error : NSError?
        var result : Int?
        
        beforeEach {
            result = nil
            database = Database.openTemporaryDatabase()
        }
        
        afterEach {
            if database.isOpen {
                database.close(nil)
            }
            database = nil
            error = nil
        }
        
        describe(".deleteFrom(tableName:whereExpr:parameters:error:)") {
            
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
        
        describe(".deleteFrom(tableName:rowIds:error:)") {
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                database.insert("contacts", row:["name": "Amelia"])
                database.insert("contacts", row:["name": "Brian"])
                database.insert("contacts", row:["name": "Cara"])
                
                result = database.deleteFrom("contacts",
                                             rowIds: [2],
                                             error:  &error)
            }
            
            it("deletes the matching values in the database") {
                var values = database.selectFrom("contacts",
                                                 columns:   ["name"],
                                                 error:     &error) { $0.stringValue("name")! }
                
                expect(result).to(equal(1))
                expect(values).to(equal(["Amelia", "Cara"]))
                expect(error).to(beNil())
            }
            
        }
        
    }
}
