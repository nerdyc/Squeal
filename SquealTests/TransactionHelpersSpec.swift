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
                        try database.insertInto("people", values: ["name":"Amelia"])
                        try database.insertInto("people", values: ["name":"Brian"])
                        try database.insertInto("people", values: ["name":"Cara"])
                    }
                    
                    expect(try! database.countFrom("people")).to(equal(3))
                }
                
            }
            
            context("when the transaction is rolled back") {
                
                it("discards changes") {
                    do {
                        try database.transaction {
                            try database.insertInto("people", values: ["name":"Amelia"])
                            try database.insertInto("people", values: ["name":"Brian"])
                            try database.insertInto("people", values: ["name":"Cara"])
                            
                            throw NSError(domain: "TransactionHelpersSpec", code: 1, userInfo: nil)
                        }
                        fail("Expected transaction to raise an error")
                    } catch let error as NSError {
                        // ensure the same error is propagated
                        expect(error.domain).to(equal("TransactionHelpersSpec"))
                    }
                    
                    expect(try! database.countFrom("people")).to(equal(0))
                }
                
            }
            
        }
        
        describe(".savepoint()") {
            
            beforeEach {
                try! database.execute("CREATE TABLE people (id PRIMARY KEY, name TEXT)")
            }
            
            context("when the savepoint is committed") {
                
                it("persists all changes") {
                    try! database.savepoint("insert_people") {
                        try database.insertInto("people", values: ["name":"Amelia"])
                        try database.insertInto("people", values: ["name":"Brian"])
                        try database.insertInto("people", values: ["name":"Cara"])
                    }
                    
                    expect(try! database.countFrom("people")).to(equal(3))
                }
                
            }
            
            context("when the transaction is rolled back") {
                
                it("discards changes") {
                    do {
                        try database.savepoint("insert_people") {
                            try database.insertInto("people", values: ["name":"Amelia"])
                            try database.insertInto("people", values: ["name":"Brian"])
                            try database.insertInto("people", values: ["name":"Cara"])
                            
                            throw NSError(domain: "TransactionHelpersSpec", code: 1, userInfo: nil)
                        }
                        fail("Expected savepoint to raise an error")
                    } catch let error as NSError {
                        // ensure the same error is propagated
                        expect(error.domain).to(equal("TransactionHelpersSpec"))
                    }
                    
                    expect(try! database.countFrom("people")).to(equal(0))
                }
                
            }
            
        }
        
    }
}
