#!/usr/bin/env ruby

# to use:
# watch ruby qtop.rb

cmd = "qstat -F"
#cmd = "cat test.qstatF"

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
    q_vals = line.split(/\s+/)
    qfields.each_with_index { |k,i| queues.last[k] = q_vals[i] }
    new_q = false
  elsif line =~ /^\t([^=]+)=(.+)/
    queues.last[$1] = $2
  end
end

class Array
  def sort_by!(&block)
    self.replace(self.sort_by(&block))
  end
end

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
  end
  def lpad(width)
    s = if self.size > width
          self[0...width]
        else
          self
        end
    s.ljust(width)
  end
end

fields = %w{ queue used/tot cpu mem load_avg mem_used mem_tot }
field_widths = [20, 10, 10, 10, 10, 10, 10]

fields.each_with_index { |s,i| fields[i] = s.lpad(field_widths[i]) }
puts fields.join

queues.each do |q|
  mem_pct = format("%.1f%%", 100.0 * q['hl:mem_used'].to_bytes / q['hl:mem_total'].to_bytes)
  cpu_pct = "#{format("%.1f",q['hl:cpu'].to_f)}%"
  info = [q['queuename'], q['used/tot.'], cpu_pct, mem_pct, q['load_avg'], q['hl:mem_used'], q['hl:mem_total']]
  info.each_with_index { |s,i| info[i] = s.lpad(field_widths[i]) }
  puts info.join
end
