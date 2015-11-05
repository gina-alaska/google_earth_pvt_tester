require_relative "framework"
require_relative "kml"
require_relative "lumber"
require_relative "handler"

cfg = Object::File.open("conf.yml"){|x| YAML.load(x)}

# So, once a upon a time it was possible to pass arguments to rackup configs via the comand line..
# then it stopped working, and life was bad.
# meanwhile, this code switched to passing arguments via the --eval line..

run Roundhouse.new(cfg)

