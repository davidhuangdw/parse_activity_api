require_relative 'init'

METRICS_OUTPUT_PATH = 'output/response_metrics.yml'

#### helpers:

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

def total_hours
  @total_hours ||=
    (config[:activity_created_at_end].to_time + 1.day -
      config[:activity_created_at_start].to_time)/1.hour
end

# Group the activities based on the user that take actions

def group_by_user(activities)
  activities.group_by{|act| act['actor']['id'] }
end


#### metrics calculation helpers:

# Helper method for calculate the response time for each activity object
def response_time(act)
  if act['type'] == 'label'
    reply_time = act['createdAt']
    target_time = (act['reply'] || act['root_message'])['postedAt']
  else
    reply_time = act['reply'] ? act['reply']['postedAt'] : act['createdAt'] # backward compatible for those old activities that hadn't saved 'reply'
    target_time = (act['parentReply'] || act['root_message'])['postedAt']
  end

  reply_time.to_time - target_time.to_time
end

# Helper method for calculate the average response time for a given group of activities
def average_response_time(activities)
  return 0.0 if activities.size == 0
  # A ruby style sum up the an array
  sum = activities.map{|act| response_time(act)}.reduce(0.0, :+)
  sum.to_f/activities.size
end


def productivity_metric(activities)
  user_response_counts = group_by_user(activities).map do|user_id, acts|
    [user_id, acts.size.to_f/total_hours]
  end.to_h
  user_response_counts.merge!('all' => activities.count.to_f/total_hours)

  { 'response_count_per_hour' => user_response_counts }
end

def response_time_metric(activities)
  user_response_times = group_by_user(activities).map do |user_id, acts|
    [user_id, average_response_time(acts)]
  end.to_h
  user_response_times.merge!('all' => average_response_time(activities))

  { 'average_response_time' => user_response_times }
end

def response_ratio_metric(activities, total_count)
  user_response_ratios = group_by_user(activities).map do |user_id, acts|
    [user_id, acts.size.to_f / total_count]
  end.to_h
  user_response_ratios.merge!('all' => activities.size.to_f/total_count)

  { 'response_ratio' => user_response_ratios }
end

#### calculate:

acts = [INTERNAL_REPLY_OUTPUT_PATH, EXTERNAL_REPLY_OUTPUT_PATH].flat_map do |messages_yml|
  messages = YAML.load_file(messages_yml)
  parse_activities(messages)
end

# productivity_metric is the result of productivity
# response_time is the result of CRT
# response_ration is the result of CRR

metrics = {
  'productivity' => productivity_metric(acts),
  'response_time' => response_time_metric(acts),
  'response_ratio' => response_ratio_metric(acts, config[:total_customer_posts])
}

File.write(METRICS_OUTPUT_PATH, metrics.to_yaml)
puts metrics.to_yaml

