# CartonDb

A pure Ruby key/value data storage system where the values may
consist of simple data structures.

The primary goals of this library are simplicity of implementation
and reliable, predictable behavior when used as intended, along
with documentation making it reasonably clear what is intended.

Secondarily, this library is optimized for fast appending to
existing entries.

## Uses

This library is useful in some of the same situations in which
one might consider using the `PStore`, `DBM`, or `SMDB` classes
provided as part of Ruby's standard library, but you either need
something more solid and trustworthy or you need something that
supports fast appending of elements to lists or sets within
entries.

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

An instance of a database class assumes nothing about the state
of the database between calls to its methods, and only expects
that the database exists and is valid when a call is made that
reads or writes data.

Only instances of database classes maintain any internal state.
No global internal state is maintained.

An empty directory is a valid empty database.

Concurrent reads from a database are supported and safe.

Writing to a database concurrently with reads or writes by
other processes or threads is not supported, and the results of
attempting to do that are unpredictable.

Initializing a new database class instance creates its directory
in the filesystem if it does not already exist. The parent of the
database directory is expected to already exist, and an exception
will be raised if it doesn't.

The database structure is designed to effectively handle up to
several million elements with any entry containing up to around
50 thousand characters (in all of the entry's elements combined).

The speed of database operations is good, and it is particularly
optimized for appending to new or existing entries. It was not
designed or optimized to be a "high performance" database
management system though, and it has not been benchmarked against
other systems for specific performance comparison. See the inline
code documentation of the classes for details about the
performance of each kind of database operation.

## Usage

The primary kind of database provided by this gem is the one
implemented by `CartonDB::ListMapDb`. It is a map of lists where
each entry has a string for a key and a list of of 0 or more
string elements as content. Other kinds of database are
implemented as specializations of that and share the same storage
format.

The name of the database is the path of a directory in the
filesystem that either already exists or shall be created as
a container for the stored data.

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
