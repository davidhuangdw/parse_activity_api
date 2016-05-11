require_relative './init'

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


ACTIVITY_TYPES.each do |activity_type|
  msgs_yml = act_yml_path(MESSAGES_OUTPUT_PATH, activity_type)
  messages = YAML.load_file(msgs_yml)

  messages['items'].each(&method(:expand_full_activities))

  msg_acts_yml = act_yml_path(MESSAGE_ACTIVITIES_OUTPUT_PATH, activity_type)
  File.write(msg_acts_yml, messages.to_yaml)
end
