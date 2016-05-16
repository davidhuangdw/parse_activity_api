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

3. fetch activities and calculate kpi metrics:

 ```bash
ruby CR_Script.rb
```

