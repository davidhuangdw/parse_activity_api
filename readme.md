# calculate activity_metric

(from engage activity api response)

### usage:

1. setup config:

    cp conf.yml.example conf.yml

2. fetch messages and output to output/messages.[type].yml

    ruby fetch_messages.rb

3. expand/fetch activities and output to output/message_activities.[type].yml

    ruby fetch_activity_messages.rb

4. parse and print productivity_metric(CRT)

    ruby calculate_productivity.rb


### helper methods:
* collect_activitie(act_type):
  * extract activities from out/message_activities.[type].yml
  * already append 'root_message'(as activity['root_message'])
