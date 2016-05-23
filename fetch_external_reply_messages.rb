require_relative 'init'

# Parameters for calling message API with activityType='label'

params = {
  bundleId: config[:bundle_id],
  userIds: conf_user_ids.join(','),
  activityCreatedAtStart: config[:activity_created_at_start].to_date.to_s,
  activityCreatedAtEnd: config[:activity_created_at_end].to_date.to_s,
  totalResults: true
}.merge(
  activityType: 'label',
  labels: config[:labels].join(',')
)

# Make API request and get all the messages with activities objects.
external_reply_messages = fetch_full_activity_messages(params)

# Write the output into 'output/external_activity_messages.yml'
File.write(EXTERNAL_REPLY_OUTPUT_PATH, external_reply_messages.to_yaml)
