# Squeal, a Swift interface to SQLite

Squeal allows [SQLite](http://www.sqlite.org/) databases to be created and accessed from 
[Swift](https://developer.apple.com/swift/) code. Squeal's goal is to make the most common SQLite tasks easy in Swift, 
while still providing complete access to SQLite's advanced features.

### Features

* Access any SQLite database, or multiple databases at a time.
* Easy interface to select rows from a database.
* Helper methods for most common types of SQL statements.
* Compile and reuse SQL for optimal performance.
* Simple DatabasePool implementation for concurrent access to a database.
* No globals.
* Thoroughly tested with [Quick](https://github.com/Quick/Quick) and [Nimble](https://github.com/Quick/Nimble).

## Installation

1.  Clone this project into your project directory. E.g.:

    ```bash
    cd ~/SwiftProject
    mkdir Externals
    git clone https://github.com/nerdyc/Squeal.git Externals/Squeal
    ```

2.  Add `Squeal.xcodeproj` to your project by selecting the 'Add files to ...' item in the 'File' menu.

3.  Add `Squeal.framework` to the `Link Binary With Libraries` section of app or framework's `Build Phases`. Be
    careful to select the framework for your platform -- Mac or iOS.
    
    You can do this by selecting your project in XCode's Project navigator (the sidebar on the left), then select
    `Build Phases` for your app or framework's target.

4.  Add Squeal's `module.map` to your project's `Import Paths`.
    
    Within your target or project's `Build Settings`, set the `Import Paths` setting to
    `$(PROJECT_DIR)/Externals/Squeal/modules`. If you cloned `Squeal` to a different location, then modify the
    example value to match.

5.  Build and run.


Step #4 (adding the `module.map`) is necessary because SQLite is a library not a module. Swift can only import 
modules, and the `module.map` defines a module for SQLite so it can be imported into Swift code.

NOTE: If see an issue like "Could not build Objective-C module 'sqlite3'", ensure you have the XCode command-line tools installed. They're required for the module.map to work correctly.

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

