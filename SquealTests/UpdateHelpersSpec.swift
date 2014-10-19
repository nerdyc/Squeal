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
            
            database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
            database.insert("contacts", row:["name": "Amelia"])
            database.insert("contacts", row:["name": "Brian"])
            database.insert("contacts", row:["name": "Cara"])
        }
        
        afterEach {
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
                var names = map(database.selectFrom("contacts", error:&error)) { $0!["name"] as String }
                expect(names).to(equal(["Amelia", "Bobby", "Cara"]))
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
                var values = map(database.selectFrom("contacts",
                                                     orderBy:"_ROWID_",
                                                     error:  &error)) { $0!["name"] as String }
                
                expect(result).to(equal(2))
                expect(values).to(equal(["Bobby", "Brian", "Bobby"]))
                expect(error).to(beNil())
            }
        }
        
    }
}
