# -*- coding: utf-8 -*-

class BarConfig
  attr_reader :colours
  attr_reader :settings
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

  def get_colours
    File.open(@settings[:colour_file]) do |f|
      JSON.parse(f.read, symbolize_names: true)
    end
  end
end

class BarFormat
  attr_reader :bar_config
  @@replacement_regex = /\$\([^\)\[\]]+\)/
  @@replacement_array_regex = /\$\(([^\)\[\]]+)\[(\d+)\]\)/
  @widgets = nil
  
  def mark_dirty(tag)
    @widgets[tag][:dirty] = true
    redraw
  end

  def set_pipe(pipe)
    @pipe = pipe
  end

  def redraw
    pipe = if @pipe.nil? then STDOUT else @pipe end
    first_pass = (@format_str.gsub(@@replacement_regex) do |match|
                    index = match.to_s[2..-2].to_sym
                    @widgets[index][:widget].read
                  end).to_s
    pipe.puts (first_pass.gsub(@@replacement_array_regex) do |match|
                 tag = $1
                 index = $2.to_i
                 array = @widgets[tag.to_sym][:widget].read
                 array[index] if not array.nil?
               end).to_s
  end
end

class LemonBarFormat < BarFormat
  def initialize(format_str, bar_config, widget_hash)
    @format_str = format_str
    @widgets = widget_hash.transform_keys(&:to_sym).transform_values do |w|
      {widget: w, dirty?: true}
    end
    @widgets.each do |t,w|
      w[:widget].set_parent(self, t)
    end
    @bar_config = bar_config
  end

  def run_bar
    @widgets.each do |t,w|
      w[:widget].run
    end
  end
end
