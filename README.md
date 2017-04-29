# CartonDb

A pure Ruby key/value data storage system where the values may
consist of simple data structures.

The primary goals of this library are simplicity of implementation
and reliable, predicatble behavior when used as intended, along
with documentation making it reasonably clear what is intended.

## Uses

Uses for this gem seem pretty limited, but you might have a
purpose for it that the author has not thought about.

This s a formalization of code that was written to solve the
specific problem of building a map of arrays in a Ruby program
that is too big for Ruby to effectively handle in RAM and to
solve it in a way that makes sense in an application with no
existing reason for a database server, using facilities available
on Heroku. Heroku does not support SQLite since folks would
mistakenly expect it to retain data that was written to it
between process instances, and Ruby's `DBM` and `SDMB` proved to
be too unpredicatable and flakey to be practical solutions.

Although this tool was initially developed to store transient data
to be used within a single process invocation and then discarded,
it is also well suited for long term data storage on a system that
preserves filesystem data over time.

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
filesystem containing the files that store the data.

A database is accessed through an instance of a database class.

An instance of a database class maintains no state in memory
between calls to its methods except the database name.

An empty directory is a valid empty database.

Concurrent reads from a database are supported and safe.

Writing to a database concurrently with reads or writes by
other processes or threads is not supported, and the results of
attempting to do that are unpredictable.

Initializing a new database class instance creates its directory
in the filesystem if it does not already exist. The parent of the
database directory is expected to exist, and an error will occur
if it doesn't

The database structure is designed to effectively handle up to
several million elements with entries containing up to 1 or 2
thousand elements each.

The speed of database operations is relatively good, but this is
not a high performance database management system. See the
documentation for the classes for more details about the
performance of particular database operations.

## Usage

Currently, this gem includes only one kind of database, which is
implemented by the `CartonDB::ListMapDb` class. It is a map of
lists where each entry has a string for a key and a list of of 0
or more string elements for a value.

The name of the database is the path of a directory that exists
or shall be created in the filesystem to contain the data files.

Example:

    require 'carton_db'

    db = CartonDb::ListMapDb.new('/tmp/my_list_map')

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
