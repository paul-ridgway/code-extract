#!/usr/bin/env ruby
require 'open3'
require 'colorize'

start_date = "2012-01-01"
end_date = "2013-12-31"
names = ["Some User"]
emails = ["user@example.com", "user@example.org"]

names.map! { |x| x.downcase }
emails.map!{ |x| x.downcase }

puts "Scanning all directories...".light_blue

# List all directories recursively
dirs = Dir.glob("**/*/") 

to_include = []

dirs.each do |d|
	# If a git repo 
	git_dir = "#{d}.git"
	if Dir.exists?(git_dir)

		# Check for commits before 
		#puts "Checking: #{d}"
		exit_status = 0
		cmd = "cd #{d} && git log --after={#{start_date}} --before={#{end_date}} --all --oneline -n 1000 --format=\"%ct\t%h\t%an\t%ae\""
		stdin, stdout, stderr, wait_thr = Open3.popen3(cmd)
		result = stdout.read.strip
		errors = stderr.read.strip
		exit_status = wait_thr.value 
		if (exit_status != 0)
			puts "#{d}:"
			puts "  Exit #{exit_status} (probably has no commits)"
			puts "  Error: #{errors}"
			next
		end
		unless result == ''
			puts "#{d}:".light_yellow
			puts "  Commits during date range specified".white
			lines = result.split("\n")
			name_emails =  lines.map{ |l| t = l.split("\t"); {date: t[0], id: t[1], name: t[2], email: t[3]}}.uniq
			puts "  Committers:".light_yellow
			any_match = false
			latest = 0
			latest_ref = ''
			name_emails.each do |ne|
				id = ne[:id]
				dt = ne[:date].to_i
				name = ne[:name]
				email = ne[:email]
				if dt > latest
					latest = dt 
					latest_ref = id
				end
				date = Time.at(dt).to_s
				name_match = names.include?(name.downcase)
				email_match = emails.include?(email.downcase)
				either_match = name_match || email_match
				any_match = true if either_match
				puts "    #{date.yellow} [#{id.yellow}] #{":".white} #{name_match ? name.light_green : name.red} #{"/".white} #{email_match ? email.light_green : email.red} - #{either_match ? "Yes".light_green : "No".red}"
			end
			puts "  Any Match: #{any_match ? "Yes".light_green : "No".red}"
			to_include << {path: d, latest: latest, ref: latest_ref} if any_match
		end
	end
end
puts "Scan Complete".light_blue

`rm -Rf /tmp/git/* ; mkdir /tmp/git`

puts "All Matches".light_yellow
to_include.each do |d|
	path = d[:path]
	date = Time.at(d[:latest]).to_s
	ref = d[:ref]
	puts "  Path: ".light_white + path.light_green
	puts "    Last Commit: ".light_white + date.light_yellow
	puts "    Ref: ".light_white + ref.light_yellow

	dir = Dir.new(path)
	src = File.expand_path(dir)
	target = "/tmp/git/#{File.basename(dir)}"
	puts "  Cloning ".light_blue + "#{src.light_yellow} " + "to".light_white + " #{target.light_yellow}"
	puts `cd /tmp/git/ && git clone #{src}` 	# Copy the repo
	puts `cd #{target} && git checkout #{ref}`	# Checkout the latest commit
	
	# Remove the reflog to protect future commits
	`cd #{target} && rm -Rf .git`			
	
	#A little cleanup (no source code or IP is deleted here)
	`cd #{target} && rm -Rf $(find . | grep .git)`

	# Protect credentials
	`cd #{target} && rm -Rf $(find . | grep DataProcessorCredentials.java)`
	`cd #{target} && rm -Rf $(find . | grep .properties)`

	# Protect client sensitive info and client IP
	`cd #{target} && rm -Rf $(find . | grep /assets)`
	`cd #{target} && rm -Rf $(find . | grep /gen)`
	`cd #{target} && rm -Rf $(find . | grep /proguard_logs)`
	`cd #{target} && rm -Rf $(find . | grep /res)`
	`cd #{target} && rm -Rf $(find . | grep .keystore)`

end

