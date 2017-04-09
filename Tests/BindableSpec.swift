import Quick
import Nimble
import Squeal

class BindableSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var statement : Statement!
        
        beforeEach {
            database = Database()
            try! database.execute("CREATE TABLE people (personId INTEGER PRIMARY KEY, name TEXT, age REAL, is_adult INTEGER, photo BLOB)")
            try! database.execute("INSERT INTO people (name, age, is_adult, photo) VALUES (\"Amelia\", 1.5, 0, NULL),(\"Brian\", 43.375, 1, X''),(\"Cara\", NULL, 1, X'696D616765')")
            // 696D616765 is "image" in Hex.
        }
        
        afterEach {
            statement = nil
            database = nil
        }
        
        describe("Statement.bind(parameters:error:)") {
            
            it("binds String values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE name IS ?")
                try! statement.bind(["Brian"])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Int values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([Int(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Int64 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([Int64(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Int32 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([Int32(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Int16 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([Int16(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Int8 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([Int8(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds UInt64 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([UInt64(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds UInt32 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([UInt32(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds UInt16 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([UInt16(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds UInt8 values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId IS ?")
                try! statement.bind([UInt8(1)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Double values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE age > ?")
                try! statement.bind([Double(43.374)] as [Bindable?])

                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Float values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE age > ?")
                try! statement.bind([Float(43.374)] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds Bool values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE is_adult IS ?")
                try! statement.bind([false])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }

            it("binds blob values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE photo IS ?")
                try! statement.bind(["image".data(using: String.Encoding.utf8)])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Cara"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds empty blob values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE photo IS ?")
                try! statement.bind([Data()] as [Bindable?])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds NULL blob values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE photo IS ?")
                try! statement.bind([nil])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds nil values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE age IS ?")
                try! statement.bind([nil])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Cara"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds multiple values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId > ? AND personId < ?")
                try! statement.bind([1, 3])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(try! statement.next()).to(equal(false))
            }
            
        }

        describe("Statement.bind(namedParameters:error:)") {
            
            it("binds named values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE name IS $NAME")
                try! statement.bind(namedParameters:[ "$NAME": "Brian" ])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(try! statement.next()).to(equal(false))
            }
            
            it("binds multiple values") {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE personId > $MIN_ID AND personId < $MAX_ID")
                try! statement.bind(namedParameters:["$MIN_ID": 1, "$MAX_ID": 3])
                
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(try! statement.next()).to(equal(false))
            }
            
        }

    }
}
