require_relative './init'

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


ACTIVITY_TYPES.each do |activity_type|
  params = params.merge(activityType: activity_type)
  result = fetch_all(url, params: params, headers: headers)

  output_yml = act_yml_path(MESSAGES_OUTPUT_PATH, activity_type)
  File.write(output_yml, result.to_yaml)
end

