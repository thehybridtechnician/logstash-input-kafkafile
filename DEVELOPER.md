logstash-input-kafkafile
====================

Kafkafile input for Logstash.  This input works like the Apache Kafka
input.  It will consume messages from a Kafka topic using the high
level consumer API.  Messages are decoded and then processed
specially.  The key 'path' should exist and point to a readable File.
This file is read, split by a 'delimiter' regex (the delimiter or
match is not included), and then processed by the specified 'codec'.
If 'delimiter' does not exist or is blank then the entire file is
processed at once.  'codec' defaults to "plain" if it is not
specified.

Each event produced is annotated with the fields from the Kafka
message.  In addition, a beginning and end event are created which
bracket the file processing.

For more information on configuration options, please see the
Logstash::Kafka input plugin.

Dependencies
====================

* Apache Kafka version 0.8.1.1
* jruby-kafka library
* logstash-plugins/logstash-input-kafka
