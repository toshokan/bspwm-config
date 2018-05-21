# -*- coding: utf-8 -*-

# Represents an abstract Widget
class Widget
  # Allow access to callback procs
  attr_accessor :mark_dirty, :colour_query
  @str = nil
  @parent = nil
  @tag = nil

  # Launches the widget by calling +task+ in a new thread
  def run
    Thread.new do
      task
    end
  end

  # This method does the work of building up +@str+ with output to display.
  def task
  end
  
  # Returns +@str+. This is a standalone to allow for overrides in special cases.
  # Overriding this might be useful for more advanced caching.
  def read
    @str
  end

  # Calls the +mark_dirty+ proc to signal to the parent BarFormat that there is new output
  def signal_parent
    mark_dirty.call()
  end
  
  # Writes +str+ to +@str+ object and calls +signal_parent()+
  def update(str)
    @str = str
    signal_parent
  end

  # Generates {LemonBar}[https://github.com/LemonBoy/bar] markup.
  # +params[:click]+ defines a command to run if we want a clickable area
  def markup(data, fg_colour, bg_colour, params = {})
    if params[:click].nil?
      "%{F#{fg_colour}}%{B#{bg_colour}} #{data} %{B-}%{F-}"
    else
      "%{F#{fg_colour}}%{B#{bg_colour}}%{A:#{params[:click]}:} #{data} %{A}%{B-}%{F-}"
    end
  end
  
  # Generates non-clickable area with standard foreground and background
  def default_markup(data, params = {})
    markup(data, get_colour(:SYS_FG), get_colour(:SYS_BG), params)
  end
  
  # Calls the +colour_query+ proc to ask the parent BarFormat for a colour code
  def get_colour(colour_name)
    colour_query.call(colour_name)
  end
end

# A widget displaying a clock
class ClockWidget < Widget
  # +format+ is a standard +Time+ format string as passed to +Time.strftime+
  def initialize(format = '%d %b %H:%M')
    @format = format
  end

  # Worker
  def task
    loop do
      @str = default_markup(Time.new.strftime(@format), click: 'notify-send "`cal`"')
      signal_parent
      sleep 5
    end
  end
end

# A widget displaying ALSA volume
class VolumeWidget < Widget
  # +input+ is the ALSA control
  def initialize(input = 'Master')
    @input = input
  end

  # Worker
  def task
    loop do
      amixerstr = `amixer get #{@input}`
      volume = /[0-9]+%/.match(amixerstr)[0].chomp('%')
      # Display 'M' if muted
      if(amixerstr.include? "[on]")
        volume += '%'
      else
        volume += 'M'
      end
      @str = default_markup(volume)
      signal_parent
      sleep 2
    end
  end
end

# A widget displaying active window title
# Uses {baskerville/xtitle}[https://github.com/baskerville/xtitle]
class WindowTitleWidget < Widget
  # Worker
  def task
    IO.popen('xtitle -s -t 150') do |io|
      io.each_line do |title|
        @str = default_markup(title.chomp)
        signal_parent
      end
    end
  end
end

# A widget displaying network traffic on the currently active of two interfaces
class NetworkWidget < Widget
  # Takes a list of interface names, in order of display priority
  def initialize(*interfaces)
    @iface0, @iface1 = interfaces
  end

  # Queries +sysfs+ to determine if interfaces is up
  def up?(iface)
    File.read("/sys/class/net/#{iface}/carrier").chomp() == '1'
  end

  # Queries +sysfs+ to determine traffic in the next 1 second
  def traffic(iface)
    fstr = lambda { |qx| "/sys/class/net/#{iface}/statistics/#{qx}_bytes" }

    rx_file = fstr.call("rx");
    tx_file = fstr.call("tx");
    rx1 = File.read(rx_file).to_i
    tx1 = File.read(tx_file).to_i
    sleep 1
    rx2 = File.read(rx_file).to_i
    tx2 = File.read(tx_file).to_i
    rx_net = (rx2 - rx1)/1024
    tx_net = (tx2 - tx1)/1024
    return "#{rx_net}↓↑#{tx_net}"
  end

  # Worker
  def task
    loop do
      if not up?(@iface0) and not up?(@iface1)
        net = nil
        sleep 30
      elsif up?(@iface0) then net = traffic(@iface0)
      elsif up?(@iface1) then net = traffic(@iface1)
      end
      @str = default_markup(net, click: 'urxvt -e "nmtui"')
      signal_parent
    end
  end
end

# A widget displaying battery percentage.
class BatteryWidget < Widget
  # +battery+ is the battery name, as in +sysfs+
  def initialize(battery = 'BAT0')
    @battery = battery
  end

  # Worker
  def task
    battery_sys_fs = "/sys/class/power_supply/#{@battery}/"
    loop do
      # Some battery controllers provide battery percentage directly
      if File.exist?(battery_sys_fs + "capacity")
        batt = File.read(battery_sys_fs + "capacity").chomp
      else
        batt_now = File.read(battery_sys_fs + "energy_now")
        batt_full = File.read(battery_sys_fs + "energy_full")
        batt = batt_now.to_f / batt_full.to_i * 100
        batt = batt.round.to_s
      end

      batt_status = File.read(battery_sys_fs+"status")
      if batt_status.include?("Discharging")
        batt += '-'
      elsif batt_status.include?("Charging")
        batt += '+'
      end
      @str = default_markup(batt.chomp)
      signal_parent
      sleep 10
    end
  end
end

# A widget displaying Bspwm monitor/desktop state
# Queries {+bspc+}[https://github.com/baskerville/bspwm]
class BspcReportListenerWidget < Widget
  # Worker
  def task
    IO.popen('bspc subscribe report') do |io|
      io.each_line do |report|
        # Report comes with a leading 'W', remove it
        @str = process_report(report[1..-1].chomp)
        signal_parent
      end
    end
  end

  # Process raw report string by monitor
  def process_report(report)
    # Split into monitors
    # Drop separators
    monitors = report.split(/(W|:)(?=[mM])/)
    monitors.delete(':')
    next_index = 1
    monitors.map do |m|
      str = process_monitor(m, next_index)
      num_desktops = (m.split(':').collect do |e|
                        /^[fFoOuU]/.match(e)
                      end).compact.length
      next_index += num_desktops
      str
    end
  end

  # Generates {LemonBar}[https://github.com/LemonBoy/bar] markup for the given monitor
  # +next_index+ is the index to assign the first desktop. This is used to generate clickable buttons with multiple monitors
  def process_monitor(monitor, next_index)
    monitor = monitor.split(':')
    monitor_name = process_monitor_name(monitor[0])
    monitor_content = monitor[1..-1].collect.with_index(offset = next_index) do |e,i|
      process_report_element(e, i)
    end
    monitor_name + monitor_content.join
  end

  # Markup monitor name based on focus
  def process_monitor_name(element)
    name = element[1..-1]
    case element
    when /^m/
      # Inactive monitor name
      fg = get_colour(:MONITOR_FG)
      bg = get_colour(:MONITOR_BG)
    when /^M/
      # Active monitor name
      fg = get_colour(:FOCUSED_MONITOR_FG)
      bg = get_colour(:FOCUSED_MONITOR_BG)
    end
    markup(name, fg, bg, click: "bspc monitor -f #{name}")
  end

  # Markup desktop based on focus
  def process_report_element(element, index)
    name = element[1..-1]
    case element
    when /^[fFoOuU]/
      case element
      when /^f/
        # Free desktop
        fg = get_colour(:FREE_FG)
        bg = get_colour(:FREE_BG)
      when /^F/
        # Focused free desktop
        fg = get_colour(:FOCUSED_FREE_FG)
        bg = get_colour(:FOCUSED_FREE_BG)
      when /^o/
        # Occupied desktop
        fg = get_colour(:OCCUPIED_FG)
        bg = get_colour(:OCCUPIED_BG)
      when /^O/
        # Focused occupied desktop
        fg = get_colour(:FOCUSED_OCCUPIED_FG)
        bg = get_colour(:FOCUSED_OCCUPIED_BG)
      when /^u/
        # Urgent desktop
        fg = get_colour(:URGENT_FG)
        bg = get_colour(:URGENT_BG)
      when /^U/
        fg = get_colour(:FOCUSED_URGENT_FG)
        bg = get_colour(:FOCUSED_URGENT_BG)
      end
      markup(name, fg, bg, click: "bspc desktop -f ^#{index}")
    when /^[LTG]/
      markup(name, get_colour(:STATE_FG), get_colour(:STATE_BG))
    end
  end
end
