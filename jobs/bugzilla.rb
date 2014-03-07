require 'net/https'
require 'json'
require 'date'
require 'yaml'

configpath = '/home/'+ENV['USER']+'/.dashing.yaml'
config = YAML.load_file(configpath)['bugzilla'] or raise("Cannot load YAML config at #{configpath}")
$url=config['url']
$path=config['path']
$max_bugs=config['max_bugs']

$WRMS_DEBUG=false

SCHEDULER.every '10m', :first_in => 0 do |job|
	bugzilla = BUGZILLA.new()

	bugs, clipped = bugzilla.needs_signoff
	count = if clipped
			   "latest #{bugs.count}, clipped"
		   else
			   bugs.count.to_s
		   end
	count = "(#{count})"
	send_event('bugs', {
		items: bugs,
		clipped: clipped,
		count: count
	})
end


class BUGZILLA
	def initialize()
		@http = Net::HTTP.new($url)
	end

	def needs_signoff
		clipped = false
		request = Net::HTTP::Get.new("#{$path}jsonrpc.cgi?" +  URI.encode('method=Bug.search&params=[{ "status": ["Needs Signoff"]}]'))
		response = @http.request(request)
		r = JSON.parse(response.body)
		bugs = []
		r['result']['bugs'].each do |bug|
			bugs << {
				link: "https://#{$url}show_bug.cgi?id=#{bug['id']}",
				label: bug['summary'],
				value: bug['status'],
				request_id: bug['id'].to_s
			}
		end
		if bugs.size > $max_bugs
			bugs = bugs[0...$max_bugs]
			clipped = true
		end
		return bugs, clipped
	end

	def sort_by_status wrs
		# Status list for ordering purposes
		statuses = [
			'New request',
			'Allocated',
			'Quoted',
			'Quote Approved',
			'In Progress',
			'Need Info',
			'Provide Feedback',
			'Development Complete',
			'Ready for Staging',
			'Catalyst Testing',
			'Failed Testing',
			'QA Approved',
			'Ready for System Test',
			'Pending QA',
			'Testing/Signoff',
			'Needs Documenting',
			'Reviewed',
			'Production Ready',
			'Ongoing Maintenance',
			'Blocked',
			'On Hold',
			'Cancelled',
			'Finished'
		]
		sorted_wrs = wrs.sort{|a,b| statuses.find_index(a[:value]) <=> statuses.find_index(b[:value]) }
		return sorted_wrs
	end
end
