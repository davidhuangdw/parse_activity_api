require_relative 'init'

params = {
  bundleId: config[:bundle_id],
  userIds: config[:user_ids].join(','),
  activityCreatedAtStart: config[:activity_created_at_start].to_date.to_s,
  activityCreatedAtEnd: config[:activity_created_at_end].to_date.to_s,
  totalResults: true
}.merge(
  activityType: 'label',
  labels: config[:ci_labels].join(',')
)

external_reply_messages = fetch_full_activity_messages(params)

File.write(EXTERNAL_REPLY_OUTPUT_PATH, external_reply_messages.to_yaml)
# puts internal_reply_messages.to_yaml
