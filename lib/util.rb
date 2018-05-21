# Utilities for multiple monitor support
module MultiMonitorUtils
  
  # Returns the number of monitors currently connected
  # Calls +xrandr+ for information.
  def MultiMonitorUtils::get_num_monitors
    `xrandr -q`.scan(/ connected/).length
  end
end
