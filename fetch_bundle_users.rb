require_relative 'init'
USERS_OUTPUT_PATH = 'output/users.yml'

url = File.join(config[:api_url], config[:users_path])
        .gsub(/:account_id/, config[:bundle_id].to_s)
params = {totalResults: true}
users = fetch_all(url, params: params, headers: headers)

if config[:output_raw_data]
  File.write(USERS_OUTPUT_PATH, users.to_yaml)
end
puts users.to_yaml

