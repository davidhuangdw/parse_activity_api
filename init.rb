require 'yaml'
require 'typhoeus'
require 'active_support/all'

USERS_OUTPUT_PATH = 'output/users.yml'
USER_ID_QUERY_LIMIT = 100
INTERNAL_REPLY_OUTPUT_PATH = 'output/internal_activity_messages.yml'
EXTERNAL_REPLY_OUTPUT_PATH = 'output/external_activity_messages.yml'
PER_REQUEST_LIMIT = 100

class RequestError < RuntimeError; end

# Method for reading all the parameters in the conf.yml

def config
  @config ||= YAML.load_file('conf.yml').with_indifferent_access
end

# Helper method for adding authentication token

def default_headers
  {
    :Authorization => "Bearer "+config[:token]
  }
end

# Helper method for making http request

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


# Method for fetching all the items when one API call doesn't return all results
# Will trigger multiple API calls and concat the results in items.

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


######### fetch full activity messages:

def parse_link(link)
  uri = URI.parse(link)
  params = URI::decode_www_form(uri.query).to_h

  uri.query = nil
  url = uri.to_s

  [url, params]
end

def expand_full_activities(msg, headers=default_headers)
  acts = msg['activities']
  return unless acts['hasMore']

  activities_link = acts['links'].find{|link| link['rel'] == 'self'}
  url, params = parse_link(activities_link['href'])

  activities = fetch_all(url, params: params, headers: headers)
  msg['activities'] = activities
end

def fetch_single_query(params, headers=default_headers)
  url = File.join(config[:api_url], config[:messages_path])

  #Fetch all messages and the response stored in the messages array
  messages = fetch_all(url, params: params, headers: headers)
  # For each message in the messages array, the function 'expand_full_activities' is
  # called to fetch all the activities in case one message has more than 10 activities
  messages['items'].each(&method(:expand_full_activities))

  puts messages['itemsSize']

  messages
end

def combine_multiple_query_results(query_results)
  total_results = count = 0
  items = []
  query_results.map do |fetch|
    total_results += fetch['totalResults']
    count += fetch['count']
    items.concat(fetch['items'])
  end

  {
    'totalResults' => total_results,
    'count' => count,
    'itemsSize' => items.size,
    'offset' => 0,
    'limit' => PER_REQUEST_LIMIT,
    'items' => items,
  }
end

def fetch_full_activity_messages(original_params, headers=default_headers)
  all_user_ids = original_params[:userIds].split(',')

  queries = all_user_ids.each_slice(USER_ID_QUERY_LIMIT).map do |user_ids|
    original_params.merge(userIds: user_ids.join(','))
  end
  query_results = queries.map{|params| fetch_single_query(params, headers)}
  combine_multiple_query_results(query_results)
end


######### user_ids:

def user_ids_from_output_yml(users_yml=USERS_OUTPUT_PATH)
  users = YAML.load_file(users_yml)
  users['items'].map{|user| user['id']}
end

def conf_user_ids
  @conf_user_ids ||= if config[:user_ids] == 'all_bundle_users'
    user_ids_from_output_yml
  else
    config[:user_ids]
  end
end

