require_relative 'init'

# Parameters for calling message API with activityType='respond'
params = {
  bundleId: config[:bundle_id],
  userIds: config[:user_ids].join(','),
  activityCreatedAtStart: config[:activity_created_at_start].to_date.to_s,
  activityCreatedAtEnd: config[:activity_created_at_end].to_date.to_s,
  totalResults: true
}.merge(activityType: 'respond')

# Make API request and get all the messages with activities objects.
internal_reply_messages = fetch_full_activity_messages(params)

# Write the output into 'output/internal_activity_messages.yml'
File.write(INTERNAL_REPLY_OUTPUT_PATH, internal_reply_messages.to_yaml)
# puts internal_reply_messages.to_yaml
