require_relative './init'

def group_by_user(activities)
  activities.group_by do |act|
    act['actor']['id']
  end.map.sort.to_h
end

def group_by_user_hour(activities)
  grp_by_user = group_by_user(activities)
  grp_by_user.map do |user_id, acts|
    grp_by_hour = acts.group_by do |act|
      Time.at((act['createdAt'].to_time.to_i/1.hour)*1.hour)
    end.map.sort.to_h

    [user_id, grp_by_hour]
  end.to_h
end

def present_groups(activity_groups, &acts_presenter)
  activity_groups.map do |user_id, user_acts|
    acts = user_acts.map do |hour, hour_acts|
      [hour, acts_presenter.call(hour_acts)]
    end.to_h
    [user_id, acts]
  end.to_h
end

activities = ACTIVITY_TYPES.flat_map(&method(:collect_activities))
# p activities.size
# p activities.first

groups = group_by_user_hour(activities)
activity_ids = present_groups(groups) do |acts|
  acts.map{|act| act['id']}.uniq
end
File.write(USRE_HOUR_ACTIVITY_OUTPUT_PATH, activity_ids.to_yaml)


user_activity_count = group_by_user(activities).map do|user_id, acts|
  [user_id, acts.size.to_f/total_hours]
end.to_h

productivity_metric = {
  'total_hours' => total_hours,
  'activity_count_per_hour' =>
    user_activity_count.merge('all' => activities.count.to_f/total_hours)
}.to_yaml

File.write(PRODUCTIVITY_OUTPUT_PATH, productivity_metric)
puts productivity_metric





