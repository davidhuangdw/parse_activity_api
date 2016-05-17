require 'yaml'
require 'typhoeus'
require 'active_support/all'

INTERNAL_REPLY_OUTPUT_PATH = 'output/internal_activity_messages.yml'
EXTERNAL_REPLY_OUTPUT_PATH = 'output/external_activity_messages.yml'
PER_REQUEST_LIMIT = 100

class RequestError < RuntimeError; end

def config
  @config ||= YAML.load_file('conf.yml').with_indifferent_access
end

def default_headers
  {
    :Authorization => "Bearer "+config[:token]
  }
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

def fetch_full_activity_messages(params, headers=default_headers)
  url = File.join(config[:api_url], config[:messages_path])

  messages = fetch_all(url, params: params, headers: headers)
  messages['items'].each(&method(:expand_full_activities))

  messages
end

