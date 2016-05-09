require 'yaml'
require 'typhoeus'
require 'active_support/all'

ACTIVITY_TYPES = %w[respond label]
MESSAGES_OUTPUT_PATH = 'output/messages.yml'
MESSAGE_ACTIVITIES_OUTPUT_PATH = 'output/message_activities.yml'
USRE_HOUR_ACTIVITY_OUTPUT_PATH = 'output/user_hour_activity_ids.yml'
PRODUCTIVITY_OUTPUT_PATH = 'output/productivity.yml'
PER_REQUEST_LIMIT = 100

class RequestError < RuntimeError; end

def config
  @config ||= YAML.load_file('conf.yml').with_indifferent_access
end

def act_yml_path(yml_path, activity_type)
  yml_path.sub(/.yml\Z/, ".#{activity_type}.yml")
end

def make_request(url, options)
  p '----making request'
  p options[:params]

  resp = Typhoeus::Request.new(url, options).run
  unless resp.success?
    p resp.code
    p resp.body
    raise RequestError
  end
  resp
end

def fetch_all(url, options)
  offset = original_offset = options[:offset] || 0
  limit = options[:limit] || PER_REQUEST_LIMIT
  count = 0
  items = []

  begin
    options[:params] = (options[:params] || {}).merge(offset: offset, limit: limit)
    resp = make_request(url, options)
    body_hash = JSON.parse(resp.body)

    items.concat body_hash['items']
    offset += limit
    count += body_hash['count']
  end while body_hash['hasMore'] && body_hash['items'].size>0

  {
    'totalResults' => body_hash['totalResults'],
    'count' => count,
    'itemsSize' => items.size,
    'offset' => original_offset,
    'limit' => limit,
    'items' => items,
  }
end

def parse_activities(messages_json)
  messages_json['items'].flat_map do |msg|
    pure_msg = msg.except('activities')

    acts = msg['activities']['items'].map do |act|
      act['root_message'] = pure_msg
      act
    end

    acts
  end
end

def collect_activities(activity_type)
  msg_acts_yml = act_yml_path(MESSAGE_ACTIVITIES_OUTPUT_PATH, activity_type)
  messages = YAML.load_file(msg_acts_yml)
  parse_activities(messages)
end

def total_hours
  (config[:activity_created_at_end].to_time - config[:activity_created_at_start].to_time)/1.hour
end


