#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'

class BarConfig
  def initialize(params = {})
    defaults = {
      wm_name: 'bspwm-panel',
      bar_height: 16,
      bar_font: 'Kochi Gothic:style=Regular:size=9',
    }
    @settings = defaults.merge params
    raise "You must specify a colour file" if @settings[:colour_file].nil?
    @colours = get_colours
  end

  def get_colours
    File.open(@settings[:colour_file]) do |f|
      JSON.parse(f.read, symbolize_names: true)
    end
  end
end

class BarFormat
  @@replacement_regex = /\$\([^\)]+\)/
  @widgets = nil
  
  def mark_dirty(tag)
    @widgets[tag][:dirty] = true
    redraw
  end

  def redraw
    puts (@format_str.gsub(@@replacement_regex) do |match|
            index = match.to_s[2..-2].to_sym
            @widgets[index][:widget].read
          end).to_s
  end
end

class LemonBarFormat < BarFormat
  def initialize(format_str, widget_hash)
    @format_str = format_str
    @widgets = widget_hash.transform_keys(&:to_sym).transform_values do |w|
      {widget: w, dirty?: true}
    end
    @widgets.each do |t,w|
      w[:widget].set_parent(self, t)
    end
  end

  def run_bar
    @widgets.each do |t,w|
      w[:widget].run
    end
    sleep
  end
end

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
end

class ClockWidget < Widget
  def initialize(format = '%d %b %H:%M')
    @format = format
  end
  
  def task
    loop do
      @str = Time.new.strftime(@format)
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
      @str = volume
      signal_parent
      sleep 1
    end
  end
end

class WindowTitleWidget < Widget
  def task
    IO.popen('xtitle -s -t 150') do |io|
      io.each_line do |title|
        @str = title.chomp
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
      @str = net
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
        batt = File.read(battery_sys_fs + "capacity")
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
      @str = batt.chomp
      signal_parent
      sleep 10
    end
  end
end

#settings = Settings.new(colour_file: '/home/toshokan/.Xresources.d/bar-colours.jsons')
clock_widget = ClockWidget.new
ckww2 = ClockWidget.new("%M")
lf = LemonBarFormat.new('battery $(batt) i love $(dogs) and $(cats) and my volume is $(vol) with current window $(wind) on my network: $(net)', dogs: clock_widget, cats: ckww2, vol: VolumeWidget.new, wind: WindowTitleWidget.new, net: NetworkWidget.new('enp0s25', 'wlp3s0'), batt: BatteryWidget.new)
lf.run_bar
