# calculate activity_metric

(from engage activity api response)

### usage:

1. setup config:

 ```bash
cp conf.yml.example conf.yml
```

2. edit 'user_ids' in conf.yml:

 ```bash
ruby fetch_bundle_users.rb
# then, change 'user_ids' in conf.yml accordingly
```

3. fetch internal_reply messages:

 ```bash
ruby fetch_internal_reply_messages.rb
```

4. fetch external_reply(add label for ci_message) messages:

 ```bash
ruby fetch_external_reply_messages.rb
```

5. calculate metrics:

 ```bash
ruby calculate_metrics.rb
```

