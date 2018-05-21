#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
require_relative 'lib/widget'
require_relative 'lib/config'
require_relative 'lib/bar'
require_relative 'lib/util'

Process.setproctitle("ruby-bar")

bar_config = BarConfig.new(colour_file: '/home/toshokan/.Xresources.d/bar-colours.json')
base_format_fn = lambda { |index| "%{l}$(bspc[#{index}])%{c}$(title)%{r}$(net) | $(batt) | $(vol) | $(sys)" }
lemonbar_format = LemonBarFormat.new(MultiMonitorUtils::build_formatter(base_format_fn),
                                     bar_config,
                                     bspc: BspcReportListenerWidget.new,
                                     title: WindowTitleWidget.new,
                                     net: NetworkWidget.new('enp0s25', 'wlp3s0'),
                                     batt: BatteryWidget.new('BAT0'),
                                     vol: VolumeWidget.new('Master'),
                                     sys: ClockWidget.new)
lemonbar = LemonBar.new(bar_config, lemonbar_format)
lemonbar.run
