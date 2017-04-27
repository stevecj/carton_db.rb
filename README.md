# CartonDb

A pure Ruby key/value data storage system where the values may
consist of simple data structures.

The primary goals of this library are simplicity of implementation
and predicatble behavior. It is developed as a reaction to Ruby's
`SDBM` which can be very flakey and unpredictable.

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

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/carton_db.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

