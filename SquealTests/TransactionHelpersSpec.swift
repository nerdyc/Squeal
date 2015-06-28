import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class TransactionHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        
        beforeEach {
            database = Database()
        }
        
        afterEach {
            database = nil
        }
        
        describe(".transaction()") {
            
            beforeEach {
                try! database.execute("CREATE TABLE people (id PRIMARY KEY, name TEXT)")
            }
            
            context("when the transaction is committed") {
                
                it("persists all changes") {
                    try! database.transaction {
                        try! $0.insertInto("people", values: ["name":"Amelia"])
                        try! $0.insertInto("people", values: ["name":"Brian"])
                        try! $0.insertInto("people", values: ["name":"Cara"])
                        
                        return .Commit
                    }
                    
                    expect(try! database.countFrom("people")).to(equal(3))
                }
                
            }
            
            context("when the transaction is rolled back") {
                
                it("discards changes") {
                    try! database.transaction {
                        try! $0.insertInto("people", values: ["name":"Amelia"])
                        try! $0.insertInto("people", values: ["name":"Brian"])
                        try! $0.insertInto("people", values: ["name":"Cara"])
                        
                        return .Rollback
                    }
                    
                    expect(try! database.countFrom("people")).to(equal(0))
                }
                
            }
            
        }
        
    }
}
