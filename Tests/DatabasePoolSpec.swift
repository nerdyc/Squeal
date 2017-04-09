import Quick
import Nimble
import Squeal

class DatabasePoolSpec: QuickSpec {
    override func spec() {
        
        var databasePool : DatabasePool!
        
        beforeEach {
            let tempPath = try! Database.createTemporaryDirectory()
            databasePool = DatabasePool(databasePath: tempPath + "/DatabasePoolSpec")
        }
        
        afterEach {
            databasePool.drain()
            databasePool = nil
        }

        describe(".dequeueDatabase(error:)") {
            
            var database : Database!
            var otherDatabase : Database?
            
            beforeEach {
                database = try! databasePool.dequeueDatabase()
            }
            
            afterEach {
                if database != nil {
                    databasePool.removeDatabase(database)
                    database = nil
                }
                
                if otherDatabase != nil {
                    databasePool.removeDatabase(otherDatabase!)
                }
                
            }
            
            it("returns a database") {
                expect(databasePool.activeDatabaseCount).to(equal(1))
                expect(databasePool.inactiveDatabaseCount).to(equal(0))
            }
            
            it("returns a new database if a database isn't available") {
                otherDatabase = try! databasePool.dequeueDatabase()
                expect(otherDatabase! !== database).to(beTruthy())
            }
            
            it("returns an existing database if one exists") {
                databasePool.enqueueDatabase(database)
                
                otherDatabase = try! databasePool.dequeueDatabase()
                expect(otherDatabase).notTo(beNil())
                expect(otherDatabase! === database).to(beTruthy())
            }
            
        }
        
        describe(".enqueueDatabase(database:)") {
            
            var database : Database!
            
            beforeEach {
                database = try! databasePool.dequeueDatabase()
            }
            
            afterEach {
                database = nil
            }
            
            it("returns the database to the queue") {
                databasePool.enqueueDatabase(database)
                
                expect(databasePool.activeDatabaseCount).to(equal(0))
                expect(databasePool.inactiveDatabaseCount).to(equal(1))
            }
            
        }
        
        describe(".removeDatabase(database:)") {
            
            var database : Database!
            
            beforeEach {
                database = try! databasePool.dequeueDatabase()
            }
            
            afterEach {
                database = nil
            }
            
            it("removes the database from the pool") {
                databasePool.removeDatabase(database)
                
                expect(databasePool.activeDatabaseCount).to(equal(0))
                expect(databasePool.inactiveDatabaseCount).to(equal(0))
            }
            
        }
        
        describe(".drain()") {
            
            var database : Database!
            var otherDatabase : Database!
            
            beforeEach {
                database = try! databasePool.dequeueDatabase()
                otherDatabase = try! databasePool.dequeueDatabase()
                
                databasePool.enqueueDatabase(otherDatabase)
            }
            
            afterEach {
                databasePool.removeDatabase(database)
                databasePool.removeDatabase(otherDatabase)
            }
            
            it("removes all unused databases from the pool") {
                expect(databasePool.activeDatabaseCount).to(equal(1))
                expect(databasePool.inactiveDatabaseCount).to(equal(1))
                
                databasePool.drain()
                
                expect(databasePool.activeDatabaseCount).to(equal(1))
                expect(databasePool.inactiveDatabaseCount).to(equal(0))
            }
            
        }
        
    }
}
