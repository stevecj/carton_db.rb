# -*- coding: UTF-8 -*-
# frozen_string_literal: true

require "carton_db/version"
require "carton_db/escaping"
require "carton_db/datum"
require "carton_db/list_map_db"
require "carton_db/simple_map_db"
require "carton_db/set_map_db"

module CartonDb
  Error = Class.new(StandardError)
  UnescapingError = Class.new(Error)
  InvalidEscapeSequence = Class.new(UnescapingError)
  IncompleteEscapeSequence = Class.new(UnescapingError)
end
