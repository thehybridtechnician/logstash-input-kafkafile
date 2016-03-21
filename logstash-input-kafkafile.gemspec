Gem::Specification.new do |s|

  s.name            = 'logstash-input-kafkafile'
  s.version         = '0.0.3.6'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = 'This input is based on the logstash-plugins/logstash-input-kafka plugin and respects its configuration.  It pulls messages from a Kafka queue and processes the file listed in the message using the configuration supplied with the message'
  s.description     = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ['Daniel Barrett','Justin Bovee']
  s.email           = ['shendaras@gmail.com','jbovee@thehybridtech.com']
  s.homepage        = "http://www.elastic.co/guide/en/logstash/current/index.html"
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','Gemfile','LICENSE']

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", ">= 2.0.0", "< 3.0.0"
  s.add_runtime_dependency "logstash-codec-json"
  s.add_runtime_dependency "logstash-codec-plain"

  s.add_runtime_dependency 'jruby-kafka', ['>= 1.5.0']
  s.add_runtime_dependency 'logstash-input-kafka', '>= 0.1.15'

  s.add_development_dependency 'logstash-devutils'

end
