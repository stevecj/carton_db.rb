# CartonDb

A pure Ruby key/value data storage system where the values may
consist of simple data structures.

The primary goals of this library are simplicity of implementation
and predicatble behavior. It is developed as a reaction to Ruby's
`SDBM` which can be very flakey and unpredictable.

## Uses

There might not actually be very many good uses for this, but it
was developed to manage a larger map of arrays than Ruby could
efficiently manage in RAM on Heroku which did not have any other
conveneint, reliable, and affordable options for that. A separate
relational database server would have been overkill, sufficiently
large Redis storage would have been expensive, and Ruby's DBM and
SDBM proved to be too unreliable and unpredictable.

## Limitations

Not designed for concurrrent access by multiple processes or
multiple threads within a Ruby process.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'carton_db'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install carton_db

## Usage

Currently, this gem includes only one kind of database, which is
implemented by the `CartonDB::ListMap` class. It is a map of lists
where each entry has a string for a key and has an array of 0 or more
strings as a value.

The name of the database is the full path to a directory in the
filesystem in which the data is stored or will be stored. The direcory
will be created if it does not already exist.

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
