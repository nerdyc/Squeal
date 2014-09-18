import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class UpdateHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var error : NSError?
        var result : Int?

        beforeEach {
            database = Database.openTemporaryDatabase()
            
            database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
            database.insert("contacts", row:["name": "Amelia"])
            database.insert("contacts", row:["name": "Brian"])
            database.insert("contacts", row:["name": "Cara"])
        }
        
        afterEach {
            if database.isOpen {
                database.close(nil)
            }
            database = nil
            error = nil
            result = nil
        }
        
        describe(".update(tableName:set:whereExpr:parameters:error:)") {
            
            beforeEach {
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
        
        describe(".update(tableName:rowIds:values:error:)") {
            
            beforeEach {
                result = database.update("contacts",
                                         rowIds:    [1, 3],
                                         values:    ["name":"Bobby"],
                                         error:     &error)
            }
            
            it("updates the values in the database") {
                var values = database.selectFrom("contacts",
                                                 columns:  ["name"],
                                                 orderBy:"_ROWID_",
                                                 error:&error) { $0.stringValue("name")! }
                
                expect(result).to(equal(2))
                expect(values).to(equal(["Bobby", "Brian", "Bobby"]))
                expect(error).to(beNil())
            }
        }
        
    }
}
