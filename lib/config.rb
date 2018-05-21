# -*- coding: utf-8 -*-

# Represents configurable option set for a bar.
class BarConfig
  # Make colours hash accessible
  attr_reader :colours
  # Make settings hash accessible
  attr_reader :settings

  # Supported params:
  # * +:wm_name+ is the panel +WM_NAME' X property.
  # * +:bar_height+ is the height in pixels of the bar
  # * +:bar_font+ is the font string sent to the bar. If using xft, use {krypt-n fork of LemonBar}[https://github.com/krypt-n/bar]
  # * +:colour_file+ is the name of a JSON file with colour definitions. *Required*
  def initialize(params = {})
    defaults = {
      wm_name: 'bspwm-panel',
      bar_height: 16,
      bar_font: 'Kochi Gothic,東風ゴシック:style=Regular:size=9',
    }
    @settings = defaults.merge params
    raise "You must specify a colour file" if @settings[:colour_file].nil?
    @colours = get_colours
  end

  # Gets colour hash from ':colour_file' setting in constructor
  def get_colours
    File.open(@settings[:colour_file]) do |f|
      JSON.parse(f.read, symbolize_names: true)
    end
  end
end

# Represents an abstract bar formatter to prepare output to be sent to the bar
class BarFormat
  # Make +BarConfig+ object accessible
  attr_reader :bar_config
  @widgets = nil

  # Mark the widget given by +tag+ as dirty and *output new data to be drawn*
  def mark_dirty(tag)
    @widgets[tag][:dirty] = true
    redraw
  end
  
  # Sets the pipe to send formatted data to
  def set_pipe(pipe)
    @pipe = pipe
  end

  # Re-output formatted data to the previously supplied pipe, according to +@format_fn+
  def redraw
    pipe = if @pipe.nil? then STDOUT else @pipe end
    widgets = @widgets.transform_values do |w|
      w[:widget].read
    end
    @format_fn.call(widgets, pipe)
  end
end

# Represents a {LemonBar}[https://github.com/LemonBoy/bar]-specific +BarFormat+
class LemonBarFormat < BarFormat
  # * +format_fn+ is a proc that will be called to serialize data for the bar
  # * +bar_config+ is a +BarConfig+ object holding settings
  # * +widget_hash+ is a Hash of widgets, indexed by their symbol in +format_fn+
  def initialize(format_fn, bar_config, widget_hash)
    @format_fn = format_fn
    @widgets = widget_hash.transform_keys(&:to_sym).transform_values do |w|
      {widget: w, dirty?: true}
    end
    colour_query = lambda { |colour_name| @bar_config.colours[colour_name] }
    @widgets.each do |t,w|
      f = lambda {mark_dirty(t)}
      w[:widget].mark_dirty = f
      w[:widget].colour_query = colour_query
    end
    @bar_config = bar_config
  end

  # Runs each widget.
  def run_bar
    @widgets.each do |t,w|
      w[:widget].run
    end
  end
end
