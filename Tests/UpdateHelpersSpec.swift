import Quick
import Nimble
import Squeal

class UpdateHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var result : Int?

        beforeEach {
            database = Database()
            
            try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT, email TEXT)")
            try! database.insert(into:"contacts", values:["name": "Amelia",  "email":"amelia@squeal.test"])
            try! database.insert(into:"contacts", values:["name": "Brian",   "email":"brian@squeal.test"])
            try! database.insert(into:"contacts", values:["name": "Cara",    "email":"cara@squeal.test"])
        }
        
        afterEach {
            database = nil
            result = nil
        }
        
        describe(".update(_:set:where:parameters:)") {
            
            beforeEach {
                result = try! database.update("contacts",
                                              set:       ["name":"Bobby", "email":"bobby@squeal.test"],
                                              where:     "name IS ?",
                                              parameters:["Brian"])
            }
            
            it("updates the values in the database") {
                expect(result).to(equal(1))

                let names = try! database.select(from:"contacts") { $0["name"] as! String }
                expect(names).to(equal(["Amelia", "Bobby", "Cara"]))
                
                let emails = try! database.select(from:"contacts") { $0["email"] as! String }
                expect(emails).to(equal(["amelia@squeal.test", "bobby@squeal.test", "cara@squeal.test"]))
            }
            
        }
        
        describe(".update(tableName:rowIds:values:error:)") {
            
            beforeEach {
                result = try! database.update("contacts",
                                              rowIds:    [1, 3],
                                              values:    ["name":"Bobby"])
            }
            
            it("updates the values in the database") {
                let values = try! database.select(from:"contacts",
                                                  orderBy:"_ROWID_") { $0["name"] as! String }
                
                expect(result).to(equal(2))
                expect(values).to(equal(["Bobby", "Brian", "Bobby"]))
            }
        }
        
    }
}
