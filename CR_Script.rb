require 'yaml'
require 'typhoeus'
require 'active_support/all'


########################
###  Helper Method   ###
########################


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
  p '----making request----'
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


def expand_full_activities(msg)
  acts = msg['activities']
  return unless acts['hasMore']

  self_link = acts['links'].find{|link| link['rel'] == 'self'}
  uri = URI.parse(self_link)
  params = URI::decode_www_form(URI.query).to_h

  uri.query = nil
  url = uri.to_s

  result = fetch_all(url, params: params, headers: headers)
  msg['activities'] = result
end


def group_by_user(activities)
  activities.group_by do |act|
    act['actor']['id']
  end
end

# To be modified

def get_response_time(activities)
  respond_time = activities.map do |act|
    reply_time = act['reply'].nil? ? act['createdAt'].to_time : act['reply']['postedAt'].to_time
    target_time = act['parentReply'].nil? ? act['root_message']['postedAt'].to_time : act['parentReply']['postedAt'].to_time
    reply_time - target_time
  end


  avg_respond_time = respond_time.reduce(:+).to_f / respond_time.size

  {
    avg: avg_respond_time,
    respond_time: respond_time
  }

end


##################################
######  Parse Logic         ######
##################################

##################################
######  1. Fetch Messages   ######
##################################

params = {
  activityType: config[:activity_type],
  bundleId: config[:bundle_id],
  userIds: config[:user_ids].join(','),
  activityCreatedAtStart: config[:activity_created_at_start].to_date.to_s,
  activityCreatedAtEnd: config[:activity_created_at_end].to_date.to_s,
  totalResults: true
}
headers = {
  Authorization: "Bearer "+config[:token]
}
url = File.join(config[:api_url], config[:messages_path])

message_result = {}

ACTIVITY_TYPES.each do |activity_type|
  params = params.merge(activityType: activity_type)
  result = fetch_all(url, params: params, headers: headers)

  message_result[activity_type.to_sym] = result
  # output_yml = act_yml_path(MESSAGES_OUTPUT_PATH, activity_type)
  # File.write(output_yml, result.to_yaml)
end


##################################
### 2. Expand all activities   ###
##################################

message_result.each do |key, value|
  #msgs_yml = act_yml_path(MESSAGES_OUTPUT_PATH, activity_type)
  messages = value

  messages['items'].each(&method(:expand_full_activities))

  if config[:output_raw_data]
    msg_acts_yml = act_yml_path(MESSAGE_ACTIVITIES_OUTPUT_PATH, key)
    File.write(msg_acts_yml, messages.to_yaml)
  end

end

##################################
### 3. calculate productivity  ###
##################################





##################################
###    4. calculate CRT        ###
##################################

# To be modified

activities = message_result.values.flat_map(&method(:parse_activities))

user_response_time = group_by_user(activities).map do |key, value|
  { key => get_response_time(value)}
end

p user_response_time



