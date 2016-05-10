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
  @total_hours ||=
    (config[:activity_created_at_end].to_time + 1.day -
      config[:activity_created_at_start].to_time)/1.hour
end

def headers
  {
    :Authorization => "Bearer "+config[:token]
  }
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

def group_by_user_hour(activities)
  grp_by_user = group_by_user(activities)
  grp_by_user.map do |user_id, acts|
    grp_by_hour = acts.group_by do |act|
      Time.at((act['createdAt'].to_time.to_i/1.hour)*1.hour)
    end.map.sort.to_h

    [user_id, grp_by_hour]
  end.to_h
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
url = File.join(config[:api_url], config[:messages_path])

message_result = ACTIVITY_TYPES.map do |activity_type|
  params = params.merge(activityType: activity_type)
  messages = fetch_all(url, params: params, headers: headers)

  # output_yml = act_yml_path(MESSAGES_OUTPUT_PATH, activity_type)
  # File.write(output_yml, messages.to_yaml)
  [activity_type.to_sym, messages]
end.to_h


##################################
### 2. Expand all activities   ###
##################################

message_result.each do |act_type, acts|
  #msgs_yml = act_yml_path(MESSAGES_OUTPUT_PATH, activity_type)
  messages = acts

  messages['items'].each(&method(:expand_full_activities))

  if config[:output_raw_data]
    msg_acts_yml = act_yml_path(MESSAGE_ACTIVITIES_OUTPUT_PATH, act_type)
    File.write(msg_acts_yml, messages.to_yaml)
  end

end

##################################
### 3. calculate productivity  ###
##################################

activities = message_result.values.flat_map(&method(:parse_activities))
# activities = ACTIVITY_TYPES.flat_map(&method(:collect_activities))

user_activity_count = group_by_user(activities).map do|user_id, acts|
  [user_id, acts.size.to_f/total_hours]
end.to_h

productivity_metric = {
  'total_hours' => total_hours,
  'activity_count_per_hour' =>
    user_activity_count.merge('all' => activities.count.to_f/total_hours)
}.to_yaml

# File.write(PRODUCTIVITY_OUTPUT_PATH, productivity_metric)
puts '========================='
puts 'Productivity:'
puts productivity_metric
puts '========================='

##################################
###    4. calculate CRT        ###
##################################

# To be modified

activities = message_result.values.flat_map(&method(:parse_activities))

user_response_time = group_by_user(activities).map do |type, acts|
  [type, get_response_time(acts)]
end.to_h

puts '========================='
puts 'CRT(customer respond time):'
puts user_response_time.to_yaml
puts '========================='

##################################
###    5. calculate CRR        ###
##################################

activities = message_result.values.flat_map(&method(:parse_activities))
# activities = ACTIVITY_TYPES.flat_map(&method(:collect_activities))

params = {
  bundleId: config[:bundle_id],
  postedAtStart: config[:posted_at_start].to_date.to_s,
  postedAtEnd: config[:posted_at_end].to_date.to_s,
}
msg_cnt_url = File.join(config[:api_url], config[:messages_count_path])
resp = make_request(msg_cnt_url, params: params, headers: headers)
total_messages_count = JSON.parse(resp.body)['count']

respond_activities = activities.select{|act| act['type'] == 'respond'}
respond_ratios = group_by_user(respond_activities).map do |user_id, acts|
  [user_id, acts.size.to_f/total_messages_count]
end.to_h

puts '========================='
puts 'CRR(customer respond ratio):'
puts respond_ratios.to_yaml
puts '========================='

