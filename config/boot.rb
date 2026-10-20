ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Bootsnap's Windows file cache cannot open source files under non-ASCII paths.
if !Gem.win_platform? || File.expand_path("..", __dir__).ascii_only?
  require "bootsnap/setup"
end
