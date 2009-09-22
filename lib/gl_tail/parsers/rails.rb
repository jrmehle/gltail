# gl_tail.rb - OpenGL visualization of your server traffic
# Copyright 2007 Erlend Simonsen <mr@fudgie.org>
#
# Licensed under the GNU General Public License v2 (see LICENSE)
#

# Parser which handles Rails access logs
class RailsParser < Parser
  def parse( line )
    #Completed in 0.02100 (47 reqs/sec) | Rendering: 0.01374 (65%) | DB: 0.00570 (27%) | 200 OK [http://example.com/whatever/whatever]
    if matchdata = /^Completed in ([\d.]+) .* \[([^\]]+)\]/.match(line)
    	_, ms, url = matchdata.to_a
	    url = nil if url == "http:// /" # mod_proxy health checks?
    #Rails 2.2.2+: Completed in 17ms (View: 0, DB: 11) | 200 OK [http://example.com/etc/etc]
    elsif matchdata = /^Completed in ([\d]+)ms .* \[([^\]]+)\]/.match(line)
    	_, new_ms, url = matchdata.to_a
	    ms = new_ms.to_f / 1000
	    url = nil if url == "http:// /" # mod_proxy health checks?
	  elsif matchdata = /Completed in ([\d]+)ms .* \[([^\]]+)\]/.match(line)
	    _, ms, url = matchdata.to_a
    end

    if url
      _, host, url = /^http[s]?:\/\/([^\/]*)(.*)/.match(url).to_a

      add_activity(:block => 'sites', :name => host, :size => ms.to_f) # Size of activity based on request time.
      add_activity(:block => 'urls', :name => HttpHelper.generalize_url(url), :size => ms.to_f)
      add_activity(:block => 'slow requests', :name => HttpHelper.generalize_url(url), :size => ms.to_f)
      add_activity(:block => 'content', :name => 'page')
      add_activity(:block => 'searches', :name => url.gsub(/^\/search\?query=/,'')) if url.include?('/search?query=')

      # Events to pop up
      add_event(:block => 'info', :name => "Logins", :message => "Login...", :update_stats => true, :color => [1.5, 1.0, 0.3, 1.0]) if url.include?('/authenticate')
      add_event(:block => 'info', :name => "Gift Purchases", :message => "$", :update_stats => true, :color => [1.5, 0.0, 6.5, 1.0]) if url.include?('/gift/thanks')
      add_event(:block => 'info', :name => "Signups", :message => "New User...", :update_stats => true, :color => [1.0, 1.0, 1.0, 1.0]) if url.include?('https') && (url.include?('/accounts') || url.include?('/accounts/create_agent'))
      add_event(:block => 'info', :name => "Search", :message => "'#{url.gsub(/^\/search\?query=/,'')}'", :update_stats => true, :color => [1.5, 0.5, 3.5, 1.0]) if url.include?('/search?query=')
    elsif line.include?('Processing ')
      #Processing TasksController#update_sheet_info (for 123.123.123.123 at 2007-10-05 22:34:33) [POST]
      _, host = /^Processing .* \(for (\d+.\d+.\d+.\d+) at .*\).*$/.match(line).to_a
      if host
        add_activity(:block => 'users', :name => host)
      end
    elsif line.include?('Error (')
      _, error, msg = /^([^ ]+Error) \((.*)\):/.match(line).to_a
      if error
        add_event(:block => 'info', :name => "Exceptions", :message => error, :update_stats => true, :color => [1.0, 0.0, 0.0, 1.0])
        add_event(:block => 'info', :name => "Exceptions", :message => msg, :update_stats => false, :color => [1.0, 0.0, 0.0, 1.0])
        add_activity(:block => 'warnings', :name => msg)

      end
    elsif line.include?('<td id="gift_total"')
      #<td id="gift_total" style="text-align: right; font-weight: bold;">$5.44</td>
      _, gift_purchase_amount = /<td id="gift_total" style="text-align: right; font-weight: bold;">\$([0-9].*\.[0-9][0-9])<\/td>/.match(line).to_a
      if gift_purchase_amount
        puts "$" + gift_purchase_amount
        add_activity(:block => 'gift purchases', :name => "Gift Purchase -- $#{gift_purchase_amount}")
      end
    end
  end
end
