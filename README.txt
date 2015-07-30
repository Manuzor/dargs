dargs
=====
A convenient way to parse (command line) string arguments.

The idea is to have one struct describe all command line parameters and filling that scruct in one go when parsing the command line arguments. Even @property functions are supported, so you could easily wrap some existing object and forward all arguments to it.

Usage
-----

Check out the `tests` folder for unit tests and samples. 

Features
--------
* Custom types are supported as long as they accept a string on the right-hand side of an assignment. Alternatively you can use a @property function to do the conversion manually (see below).
* `@property` functions are treated as variables. Taking a string, the user can parse a string argument themselves to whatever value they wish.

### Limitations of @property functions
Due to technical limitations, you have two options when using @property functions:
1. Provide a getter _and_ a setter of any type where `std.conv.to!YourType("argValue")` works.
1. When only providing a setter, it has to accept a string as its argument.

Only providing a getter will not work for obvious reasons... If your struct needs a getter, use `@Hidden` to hide it.
