#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
require_relative 'lib/widget'
require_relative 'lib/config'
require_relative 'lib/bar'
require_relative 'lib/util'

Process.setproctitle("ruby-bar")

bar_config = BarConfig.new(colour_file: '/home/toshokan/.Xresources.d/bar-colours.json')

# Formatter should accept a widget hash and a monitor number
format = lambda { |w,m| "%{l}#{w[:bspc][m] unless w[:bspc].nil?}%{c}#{w[:title]}%{r}#{w[:net]} | #{w[:batt]} | #{w[:vol]} | #{w[:sys]}" }

lemonbar_format = LemonBarFormat.new(MultiMonitorUtils::gen_format_fn(format),
                                     bar_config,
                                     bspc: BspcReportListenerWidget.new,
                                     title: WindowTitleWidget.new,
                                     net: NetworkWidget.new('enp0s25', 'wlp3s0'),
                                     batt: BatteryWidget.new('BAT0'),
                                     vol: VolumeWidget.new('Master'),
                                     sys: ClockWidget.new)
lemonbar = LemonBar.new(bar_config, lemonbar_format)
lemonbar.run
