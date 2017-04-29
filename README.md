# CartonDb

A pure Ruby key/value data storage system where the values may
consist of simple data structures.

The primary goals of this library are simplicity of implementation
and reliable, predicatble behavior when used as intended, along
with clear enough documentation so that it is clear how it is
intended to be used.

## Uses

Uses for this might be quite limited, but you might have a
purpose for it that the author has not thought of.

This gem is a formalization of code that was written to solve the
specific problem of how to build a map of arrays that is too big
for Ruby to effectively handle in RAM on Heroku, which does not
have many convenient alternatives.  A relational database would
have worked but would have been weird since the app had no other
use for a database server, and SQLite is explicitly not supported.
Ruby's `DBM` and `SDMB` each seemed like a workable solution, but
in practice, both turned out to be flakey, unpredicatble, and
basically unusable.

Although the solution was developed for the Heroku case in which
there was no guarantee that data stored on disk would be
be retained between processes, it is a perfectly good solution
for persistent data when run on a system that does retain disk
storage over time.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'carton_db'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install carton_db

## Characteristics

Each database has a name which is the path of a directory in the
filesystem within which the files holding the database contents
are stored.

A database is accessed through an instance of a database class.

An instance of a database class does not maintain any state in
memory between calls to its methods except the datbase name.

An empty directory constitutes a valid empty database.

Concurrent reads from a database are supported and safe.

Writing to a database concurrently with reads or writes by
another process or thread is not supported, and the results of
doing so are unpredictable.

Creating an instance of a database class creates the database
directory if it does not already exist. It does not create the
containing directory heirarchy however, and an error will occur
if the parent directory does not exist.

The database structure is designed to effectively handle up to
a few million elements with entries containing up to a few
thousand elements each.

Performance is nothing special, but not too terrible either.
See the documentation for the classes for more details about the
performance of each operation.

## Usage

Currently, this gem includes only one kind of database, which is
implemented by the `CartonDB::ListMap` class. It is a map of lists
where each entry has a string for a key and has an array of 0 or
more strings as a value.

The name of the database is the full path to a directory in the
filesystem in which the data is stored or will be stored. The
direcory will be created if it does not already exist.

Example:

    require 'carton_db'

    db = CartonDb::ListMap.new('/tmp/my_list_map.cdblm')

    db['Some Key'] = ['element 1', 'element 2']

    db['Another Key'] = []

    db.append_to 'Yet Another', 'abc'
    db.append_to 'Yet Another', 'def'

    p db.count
    # 3

    p db['Some Key']
    # ["element 1", "element 2"]

    p db['Another Key']
    # []

    p db['Yet Another']
    # ["abc", "def"]

    p db['Something Else']
    # nil

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake
install`. To release a new version, update the version number in
`version.rb`, and then run `bundle exec rake release`, which will
create a git tag for the version, push git commits and tags, and push
the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/[USERNAME]/carton_db.


## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
