module ApplicationHelper
    
    def short_datetime(d)
        d.in_time_zone('Pacific Time (US & Canada)').to_formatted_s(:short)
    end
end
