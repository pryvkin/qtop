#!/usr/bin/env ruby
# qtop
#
# Monitor resource usage of a cluster
# To use:
#   watch ruby qtop.rb
#
#Copyright (C) 2010 Paul Ryvkin <paulnik@gmail.com>
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

cmd = "qstat -F"
#cmd = "cat beta.qstat"

qstat_text = `#{cmd}`

queues = []
first_line = true
qfields = ''
new_q = false

qstat_text.each_line do |line|
  line.chomp!

  if first_line
    first_line = false
    qfields = line.split(/\s+/)
  end

  if line =~ /^-+$/
    new_q = true

  elsif new_q
    queues << Hash.new
    queues.last['index'] = queues.size-1
    line.split(/\s+/).each_with_index { |val, i| queues.last[qfields[i]] = val }
    new_q = false

  elsif line =~ /^\t([^=]+)=(.+)/
    queues.last[$1] = $2
  end
end

# some queues report 'resv/used/tot.' instead of 'used/tot.'
queues.each do |q|
  q.each do |key, val|
    if key =~ /used\/tot.$/
      q['used/tot.'] = val.split(/\//)[-2..-1].join("/")
    end
  end
end

# sort descending by nodes used then by qstat's reporting order
queues.sort! do |q1,q2|
  used_cmp = q2['used/tot.'].split(/\//).first.to_i <=> q1['used/tot.'].split(/\//).first.to_i
  if used_cmp != 0
    used_cmp
  else
    q1['index'] <=> q2['index']
  end
end

class String
  def to_bytes
    self =~ /(.+?)([^0-9]{0,1})$/
    pre = $1.to_f
    suffix = $2 if $2
    if suffix
      case suffix.upcase
      when "K"; pre *= 1e3
      when "M"; pre *= 1e6
      when "G"; pre *= 1e9
      end
    end
    return pre
  end
  def trunc(width)
    self[0...([self.size, width].min)]
  end
  def pad(width, just)
    self.trunc(width).send(just, width)
  end
end

fields = %w{ queue nodes cpu mem load_avg mem_used mem_tot }
field_widths = [27, 7, 7, 7, 7, 9, 9]
field_justs = [:ljust, :rjust, :rjust, :rjust, :rjust, :rjust, :rjust]

fields.each_with_index { |s,i| fields[i] = s.pad( field_widths[i], field_justs[i]) }
puts fields.join(' ')

begin
  queues.each do |q|
    cpu_pct, mem_pct, load_avg, mem_used, mem_total = ['-NA-']*5
    
    if !q['states'] || q['states'] !~  /[au]/
      cpu_pct = "#{format("%.1f",q['hl:cpu'].to_f)}%"
      
      mem_pct = format("%.1f%%", 100.0 * q['hl:mem_used'].to_bytes / q['hl:mem_total'].to_bytes)
      
      load_avg, mem_used, mem_total = q.values_at(*%w{ load_avg hl:mem_used hl:mem_total } )
    end
    
    info = [q['queuename'], q['used/tot.'], cpu_pct, mem_pct, load_avg, mem_used, mem_total]
    info.each_with_index { |s,i| info[i] = s.pad( field_widths[i], field_justs[i]) }
    puts info.join(' ')
  end
rescue Errno::EPIPE
  # sometimes watch will kill stdout while ruby's trying to write to it
  # thus causing ruby to print an ugly "broken pipe" msg. this prevents that
  exit
end
