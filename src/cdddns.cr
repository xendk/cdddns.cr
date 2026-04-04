require "docr"
require "file_utils"
require "option_parser"
require "./cdddns/docker"
require "./cdddns/models"
require "./cdddns/metadata_extractor"

# A simple Docker "DNS service".
module Cdddns
  VERSION = "0.1.0"
end
