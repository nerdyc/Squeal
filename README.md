# Squeal, a Swift interface to SQLite

Squeal provides access to [SQLite](http://www.sqlite.org/) databases in Swift. Its goal is to provide a
simple and straight-forward API, without much magic.
    
Squeal provides some helpers to generate and execute the most common SQL statements, and take the drudgery out of generating these yourself. However, it's not a goal of this project to hide SQL from the developer, or to provide a generic object-mapping on top of SQLite.

### Features

* Access any SQLite database, or multiple databases at a time.
* Easy interface to select rows from a database.
* Helper methods for most common types of SQL statements.
* Compile and reuse SQL for optimal performance.
* Simple DatabasePool implementation for concurrent access to a database.
* No globals.
* Thoroughly tested with [Quick](https://github.com/Quick/Quick) and [Nimble](https://github.com/Quick/Nimble).


## Installation

Squeal can be installed via [Carthage](https://github.com/Carthage/Carthage) or [CocoaPods](https://cocoapods.org).


### Carthage

To install using Carthage, simply add the following line to your `Cartfile`:

    github "nerdyc/Squeal"


### CocoaPods

To install using Carthage, simply add the following to the appropriate target in your `Podfile`:

    pod "Squeal"


## Usage

To get an overview of using Squeal, please check out the playground included in the project.

## License

Squeal is released under the MIT License. Details are in the `LICENSE.txt` file in the project.

## Contributing

Contributions and suggestions are very welcome! No contribution is too small. Squeal (like Swift) is still evolving and feedback from the community is appreciated. Open an Issue, or submit a pull request!

The main requirement is for new code to be tested. Nobody appreciates bugs in their database.

### Testing

Squeal benefits greatly from the following two testing libraries:

* [Quick](https://github.com/Quick/Quick)
  
  Quick provides BDD-style testing for Swift code. Check out their examples, or Squeal's own tests for examples.
  
* [Nimble](https://github.com/Quick/Nimble)
  
  Nimble provides clean, extensible matchers for Swift tests.

