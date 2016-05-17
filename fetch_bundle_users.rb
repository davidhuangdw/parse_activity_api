require_relative 'init'
USERS_OUTPUT_PATH = 'output/users.yml'

url = File.join(config[:api_url], config[:users_path])
        .gsub(/:account_id/, config[:bundle_id].to_s)
params = {totalResults: true}

# Make the API call to fetch all the users belong to the bundle
users = fetch_all(url, params: params, headers: default_headers)

# Write the response into the 'output/users.yml'
File.write(USERS_OUTPUT_PATH, users.to_yaml)
puts users.to_yaml

