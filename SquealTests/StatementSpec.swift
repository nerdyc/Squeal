import Quick
import Nimble
import Squeal

class StatementSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var statement : Statement!
        var tempPath : String!
        var error : NSError?
        
        beforeEach {
            tempPath = createTemporaryDirectory()
            database = Database(path:tempPath + "/Squeal")
            database.open()
            
            database.execute("CREATE TABLE people (personId INTEGER PRIMARY KEY, name TEXT, age REAL, is_adult INTEGER)")
            database.execute("INSERT INTO people (name, age, is_adult) VALUES (\"Amelia\", 1.5, 0),(\"Brian\", 43.375, 1),(\"Cara\", NULL, 1)")
        }
        
        afterEach {
            statement = nil
            database = nil
            error = nil
        }
        
        // =============================================================================================================
        // MARK:- QUERY
        
        describe("next(error:)") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age FROM people")
            }
            
            it("advances to the next row, returning false when there are no more rows") {
                expect(statement.next()).to(beTruthy())
                expect(statement.columnCount).to(equal(3))
                expect(statement.columnNames).to(equal(["personId", "name", "age"]))
                
                expect(statement.indexOfColumnNamed("personId")).to(equal(0))
                expect(statement.indexOfColumnNamed("name")).to(equal(1))
                expect(statement.indexOfColumnNamed("age")).to(equal(2))
                
                expect(statement.nameOfColumnAtIndex(0)).to(equal("personId"));
                expect(statement.nameOfColumnAtIndex(1)).to(equal("name"));
                expect(statement.nameOfColumnAtIndex(2)).to(equal("age"));
                
                // 0: id:1, name:Amelia, age:1.5
                expect(statement.integerValueAtIndex(0)).to(equal(1))
                expect(statement.integerValue("personId")).to(equal(1))
                expect(statement.stringValueAtIndex(1)).to(equal("Amelia"))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.realValueAtIndex(2)).to(equal(1.5))
                expect(statement.realValue("age")).to(equal(1.5))
                
                // 1: id:2, Brian, age:43.375
                expect(statement.next()).to(beTruthy())
                expect(statement.integerValueAtIndex(0)).to(equal(2))
                expect(statement.integerValue("personId")).to(equal(2))
                expect(statement.stringValueAtIndex(1)).to(equal("Brian"))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(statement.realValueAtIndex(2)).to(equal(43.375))
                expect(statement.realValue("age")).to(equal(43.375))
                
                // 2: id:3, name:Cara, age:nil
                expect(statement.next()).to(beTruthy())
                expect(statement.integerValueAtIndex(0)).to(equal(3))
                expect(statement.integerValue("personId")).to(equal(3))
                expect(statement.stringValueAtIndex(1)).to(equal("Cara"))
                expect(statement.stringValue("name")).to(equal("Cara"))
                expect(statement.realValueAtIndex(2)).to(beNil())
                expect(statement.realValue("age")).to(beNil())
                
                expect(statement.next()).to(beFalsy())
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Parameters
        
        describe("bind(parameters:error:)") {
            
            it("binds String values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE name IS ?")
                statement.bind("Brian")
            
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Brian"))
                
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Int values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(Int(1))

                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Int64 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(Int64(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Int32 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(Int32(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Int16 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(Int16(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Int8 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(Int8(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds UInt64 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(UInt64(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds UInt32 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(UInt32(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds UInt16 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(UInt16(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds UInt8 values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                statement.bind(UInt8(1))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Double values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE age > ?")
                statement.bind(Double(43.374))

                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Float values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE age > ?")
                statement.bind(Float(43.374))
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds Bool values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE is_adult IS ?")
                statement.bind(false)
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.next()).to(beFalsy())
            }
            
            it("binds nil values") {
                statement = database.prepareStatement("SELECT * FROM people WHERE age IS ?")
                statement.bind([nil], error:&error)
                
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Cara"))
                expect(statement.next()).to(beFalsy())
            }
            
        }
        
        describe("reset()") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT * FROM people WHERE name IS ?")
                statement.bind("Brian")
                statement.next()
                statement.reset()
            }
            
            it("resets the statement so it can be executed again") {
                expect(statement.next()).to(beTruthy())
                expect(statement.stringValue("name")).to(equal("Brian"))
            }
            
        }
        
        describe("parameterCount") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT * FROM people WHERE name IS ? AND age > ?")
            }
            
            it("returns the number of parameters") {
                expect(statement.parameterCount).to(equal(2))
            }
            
        }
        
    }
}

