#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
require_relative 'lib/widget'
require_relative 'lib/config'
require_relative 'lib/bar'
require_relative 'lib/util'

Process.setproctitle("ruby-bar")

bar_config = BarConfig.new(colour_file: '/home/toshokan/.Xresources.d/bar-colours.json')

# Dispatch formatter function that accepts a number of monitors, a widget hash, and a pipe to write output to.
def format_fn(monitors, w, p)
  inner_fm = lambda { |m| "%{l}#{w[:bspc][m] unless w[:bspc].nil?}%{c}#{w[:title]}%{r}#{w[:net]} | #{w[:batt]} | #{w[:vol]} | #{w[:sys]}" }
  str = ""
  monitors.times do |i|
    str += if(i != 0) then "%{S+}" else "" end
    str += inner_fm.call(i)
  end
  p.puts str
end

lemonbar_format = LemonBarFormat.new(method(:format_fn).curry.call(MultiMonitorUtils::get_num_monitors),
                                     bar_config,
                                     bspc: BspcReportListenerWidget.new,
                                     title: WindowTitleWidget.new,
                                     net: NetworkWidget.new('enp0s25', 'wlp3s0'),
                                     batt: BatteryWidget.new('BAT0'),
                                     vol: VolumeWidget.new('Master'),
                                     sys: ClockWidget.new)
lemonbar = LemonBar.new(bar_config, lemonbar_format)
lemonbar.run
