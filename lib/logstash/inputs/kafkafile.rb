require 'logstash/namespace'
require 'logstash/inputs/base'
require 'logstash/inputs/kafka'

class LogStash::Inputs::KafkaFile < LogStash::Inputs::Kafka
  #
  # This plugin is designed to take a kafka message in json that specifies a file
  # and then reads it into Logstash
  # Example Configuration
  # -------------------------------------------------------------------------
  # input {
  #   kafkafile {
  #     zk_connect => "localhost:2181"
	#    	tags => [ "kafkafile","file" ]
	#   	topic_id => "logstash"
	#   	group_id => "logstash"
  #   }
  # }
  # -------------------------------------------------------------------------
  # File values are past in the json message.
  # Example Message
  # -------------------------------------------------------------------------
  # { "type": "syslog", "path":"/data02/logs/4145098143/messages", "delimiter":"\n" }
  # { "type": "netStatPerIp", "path":"/data02/commands/13431134/netStatPerIp", "delimiter":"\\w{3}\\s+\\w{3}\\s+\\d+\\s+\\d{2}:\\d{2}:\\d{2}\\s+\\w+\\s\\d{4}"}
  # { "type": "sarData", "path":"/data02/metrics/134314/sar05", "codec":"sar", "delimiter":"\n"}
  # -------------------------------------------------------------------------
  # Example logstash command to run
  # -------------------------------------------------------------------------
  # bin/logstash agent -e 'input { kafkafile { zk_connect => "localhost:2182" topic_id => "logstash" } } output { stdout { codec => rubydebug } }'
  # -------------------------------------------------------------------------
  config_name 'kafkafile'

  default :codec, 'json'

  config :read_size, :validate => :number, :default => 8192

  private
  def valid_string?(x)
    return false if x.nil?
    return false unless x.kind_of?(String)
    return true
  end

  private
  def non_empty_string?(x)
    return false unless valid_string?(x)
    return false if x.length < 1
    return true
  end

  private
  def combine_events(a, b)
    clone = a.clone()

    h = b.to_hash
    h.each do |k,v|
      clone[k] = v
    end

    return clone
  end

  private
  def send_status_event(status, event, output_queue, opts)
    status_h = Hash.new
    status_h['type'] = 'fileMetrics'
    status_h['status'] = status
    status_h['logDate'] = (Time.new).iso8601(10)

    unless opts.nil?
      status_h.merge!(opts)
    end

    status_evt = LogStash::Event.new(status_h)
    output_queue << combine_events(event, status_evt)
  end

  private
  def queue_event(message_and_metadata, output_queue)
    begin
      @codec.decode("#{message_and_metadata.message}") do |event|
        decorate(event)
        if @decorate_events
          event['kafka'] = {'msg_size' => message_and_metadata.message.size,
                            'topic' => message_and_metadata.topic,
                            'consumer_group' => @group_id,
                            'partition' => message_and_metadata.partition,
                            'key' => message_and_metadata.key}
        end

        # check for required fields in the message
        unless non_empty_string?(event['path'])
          @logger.error('Message did not include proper field "path"', :message => "#{message_and_metadata.message}")
          return
        end
        path = event['path']

        unless valid_string?(event['delimiter'])
          @logger.error('Message did not include required field "delimiter"', :message => "#{message_and_metadata.message}")
          return
        end

        del = nil
        if non_empty_string?(event['delimiter'])
          del = Regexp.new(event['delimiter'])
        end

        stat = File.stat(path)

        unless stat.readable?
          @logger.error('Failed to stat file from message', :message => "#{message_and_metadata.message}")
          return
        end

        event['fileStats'] = {'atime' => stat.atime,
#                              'birthtime' => stat.birthtime,
                              'ctime' => stat.ctime,
                              'mtime' => stat.mtime,
                              'size' => stat.size}

        file_codec_klass = LogStash::Plugin.lookup("codec", event['codec'] || "plain")
        if file_codec_klass.nil?
          @logger.error('Did not find class for codec', :message => "#{message_and_metadata.message}")
          return
        end
        file_codec = file_codec_klass.new
## Adding charset
	if event['charset']
          file_codec::charset = event['charset']
	  file_codec.register
	end

        send_status_event('begin', event, output_queue, nil)

        segment_index = 0
        File.open(event['path'], 'r') do |file|
          split_on_delimiter(file, del) do |segment|
            file_codec.decode(segment) do |file_evt|

              evt = combine_events(event, file_evt)
              evt['fileStats']['segmentIndex'] = segment_index
              segment_index = segment_index + 1
              output_queue << evt
            end # decode
          end # split
        end # open

        file_codec.flush do |file_evt|
          evt = combine_events(event, file_evt)
          evt['fileStats']['segmentIndex'] = segment_index
          segment_index = segment_index + 1
          output_queue << evt
        end # flush

        send_status_event('end', event, output_queue, { "segmentCount" => segment_index})
      end # @codec.decode
    rescue => e # parse or event creation error
      @logger.error('Failed to create event', :message => "#{message_and_metadata.message}", :exception => e,
                    :backtrace => e.backtrace)
    end # begin
  end # def queue_event

  def split_on_delimiter(file, del)
    # without a delimiter, just yield the entire file
    if del.nil?
      yield file.read
      return
    end

    save = ""
    last_del = ""
    loop do
      buf = file.read(@read_size)

      if buf.nil?
        if save && save.length > 0
          # yield whatever we have in the buffer
          # the next iteration will break the loop
          yield last_del << save
          save = nil
          next
        else
          break
        end
      end # buf.nil?

      save << buf
      loop do
        scan = StringScanner.new(save)
        if scan.scan_until(del).nil?
          # no match, just let save accumulate
          break
        end

        # had a match, yield pre, save post
        if last_del =~ /\n/
            segment = scan.pre_match
        else
            segment = last_del << scan.pre_match
        end

        save = scan.rest
        last_del = scan.matched

        yield segment if non_empty_string?(segment)

      end # loop for scan
     end # loop
  end # def split_on_delimiter
end #class LogStash::Inputs::KafkaFile
