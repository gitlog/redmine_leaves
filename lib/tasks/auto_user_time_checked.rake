namespace :redmine_leaves do
	task auto_check_in: :environment do

		if Setting.plugin_redmine_leaves['time_loggers_group'].to_i > 0

			users = User.active.in_group(Setting.plugin_redmine_leaves['time_loggers_group'].to_i)
			
			users.each do |user|

				checkin_timechecks = UserTimeCheck.where(['user_id = ? AND check_out_time IS NULL', user.id])

				if checkin_timechecks.empty?

					tmp = Redmine::Activity::Fetcher.new(user, :author => user)

					unless tmp.blank?

						activity = tmp.events(Time.now.to_date, Time.now.to_date + 1)

						unless activity.blank?

							activity.select! { |hash| hash[:created_on] >= Time.now.utc.to_date }

							event = activity.last

							if event.event_datetime.hour <= Time.now.hour - 2
								@user_time_check = UserTimeCheck.create(user_id: user.id, check_in_time: event.event_datetime, :comments => "Auto check in")
							end
						end
					end
				else

					tmp = Redmine::Activity::Fetcher.new(user, :author => user)

					unless tmp.blank?

						activity = tmp.events(Time.now.to_date, Time.now.to_date + 1)

						unless activity.blank?

							event = activity.first

							if event.event_datetime.hour <= Time.now.utc.hour - 6
								@check_out_time = event.event_datetime.to_datetime
								@elapsed_seconds = ((@check_out_time -  DateTime.parse(checkin_timechecks.first.check_in_time.to_s)) * 24 * 60 * 60).to_i
								checkin_timechecks.first.update_attributes(:check_out_time => event.event_datetime, :time_spent => @elapsed_seconds, :comments => "Auto check out") 
							end
						end
					end
				end
			end
		end
	end
end
