# Utilities for multiple monitor support
module MultiMonitorUtils
  
  # Returns the number of monitors currently connected
  # Calls +xrandr+ for information.
  def MultiMonitorUtils::get_num_monitors
    `xrandr -q`.scan(/ connected/).length
  end

  # Yields a proc to use a format function. The input is an initial format function written for a single monitor.
  # The input function should take two paramters, a hash of widgets and a monitor number.
  # The returned proc will be configured for the amount of monitors available when this method is called.
  def MultiMonitorUtils::gen_format_fn(inner_f)
    format_fn = Proc.new { |monitors, widgets, pipe| 
      str = ""
      monitors.times do |i|
        str += if(i != 0) then "%{S+}" else "" end
        str += inner_f.call(widgets, i)
      end
      pipe.puts str
    }
    format_fn.curry.call(MultiMonitorUtils::get_num_monitors)
  end
end
