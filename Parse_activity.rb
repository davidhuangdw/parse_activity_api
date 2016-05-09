require 'typhoeus'
require 'yaml'

options = YAML.load(File.open('parameters.yml'))

# select method based on the yml option
# Add case logic here





########################
# API Call Helper Method
########################

def get_activity_messages(options)

end


def get_activities(options)

end

def make_request(options)

  # request = Typhoeus::Request.new(
  #   url(path),
  #   :method => 'get',
  #   :headers => request_headers(options),
  #   :body => options[:body],
  #   :params => options[:params])
  #
  # response = request.run

end


