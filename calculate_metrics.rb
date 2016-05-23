require_relative 'init'

METRICS_OUTPUT_PATH = 'output/response_metrics.yml'

#### helpers:

def parse_activities(messages_json)
  messages_json['items'].flat_map do |msg|
    pure_msg = msg.except('activities')

    # Collect activities from each message['activities']['items']. And inside each activity object, store extra field: 'root_message'
    # (Please refer to file 'output/internal_activity_messages.yml' for messages_json structure)
    acts = msg['activities']['items'].map do |act|
      # intentionally add 'root_message' field for post-processing of activity object
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
  activities.group_by{|act| "#{act['actor']['id']} -- #{act['actor']['email']}" }
end


#### metrics calculation helpers:

def post_time(message)
  message['threadPostedAt'] || message['postedAt']    # use 'threadPostedAt' for direct_message
end

# Helper method for calculate the response time for each activity object
def response_time(act)
  # 1. for external reply outside engage, we'll add label to the target message
  if act['type'] == 'label'
    # have to use activity['createdAt'], because reply is outside and thus not stored in activity object
    reply_time = act['createdAt']

    # when replying to a comment externally, we will add label to the target_comment which is saved as act['reply'](for 'label' activity); otherwise target should be act['root_message']
    target_time = post_time(act['reply'] || act['root_message'])


  # 2. for internal reply inside engage
  else
    reply_time = act['reply'] ? post_time(act['reply']) : act['createdAt'] # backward compatible for those old activities that hadn't saved 'reply', we have to use act['createdAt']


    # when replying to a comment internally, the target_comment will be saved as activity['parentReply'](for 'respond' activity); otherwise target should be act['root_message']
    target_time = post_time(act['parentReply'] || act['root_message'])
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
    [user_id, acts.size.to_f / total_count]           # ratio == customer_response_count/total_customers_response_count
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

