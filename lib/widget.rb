# -*- coding: utf-8 -*-

class Widget
  @str = nil
  @parent = nil
  @tag = nil
  
  def run
    Thread.new do
      task
    end
  end

  def task
  end
  
  def read
    @str
  end
  
  def set_parent(bar_format, tag)
    @parent = bar_format
    @tag = tag
  end

  def signal_parent
    @parent.mark_dirty(@tag)
  end

  def update(str)
    @str = str
    signal_parent
  end

  def markup(data, fg_colour, bg_colour, params = {})
    if params[:click].nil?
      "%{F#{fg_colour}}%{B#{bg_colour}} #{data} %{B-}%{F-}"
    else
      "%{F#{fg_colour}}%{B#{bg_colour}}%{A:#{params[:click]}:} #{data} %{A}%{B-}%{F-}"
    end
  end

  def default_markup(data, params = {})
    markup(data, get_colour(:SYS_FG), get_colour(:SYS_BG), params)
  end

  def bar_config
    @parent.bar_config
  end

  def get_colour(colour_name)
    @parent.bar_config.colours[colour_name]
  end
end

class ClockWidget < Widget
  def initialize(format = '%d %b %H:%M')
    @format = format
  end
  
  def task
    loop do
      @str = default_markup(Time.new.strftime(@format), click: 'notify-send "`cal`"')
      signal_parent
      sleep 1
    end
  end
end

class VolumeWidget < Widget
  def initialize(input = 'Master')
    @input = input
  end

  def task
    loop do
      amixerstr = `amixer get #{@input}`
      volume = /[0-9]+%/.match(amixerstr)[0].chomp('%')
      if(amixerstr.include? "[on]")
        volume += '%'
      else
        volume += 'M'
      end
      @str = default_markup(volume)
      signal_parent
      sleep 1
    end
  end
end

class WindowTitleWidget < Widget
  def task
    IO.popen('xtitle -s -t 150') do |io|
      io.each_line do |title|
        @str = default_markup(title.chomp)
        signal_parent
      end
    end
  end
end

class NetworkWidget < Widget
  def initialize(*interfaces)
    @iface0, @iface1 = interfaces
  end

  def up?(iface)
    File.read("/sys/class/net/#{iface}/carrier").chomp() == '1'
  end

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

class BatteryWidget < Widget
  def initialize(battery = 'BAT0')
    @battery = battery
  end

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

class BspcReportListenerWidget < Widget
  def task
    IO.popen('bspc subscribe report') do |io|
      io.each_line do |report|
        # Report comes with a leading 'W', remove it
        @str = process_report(report[1..-1].chomp)
        signal_parent
      end
    end
  end

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

  def process_monitor(monitor, next_index)
    monitor = monitor.split(':')
    monitor_name = process_monitor_name(monitor[0])
    monitor_content = monitor[1..-1].collect.with_index(offset = next_index) do |e,i|
      process_report_element(e, i)
    end
    monitor_name + monitor_content.join
  end

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
