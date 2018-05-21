module MultiMonitorUtils
  def MultiMonitorUtils::get_num_monitors
    `xrandr -q`.scan(/ connected/).length
  end

  def MultiMonitorUtils::build_format_str(base_format_fn, num_monitors)
    str = ""
    num_monitors.times do |i|
      base = if i == 0 then "" else "%{S+}" end
      str += (base + base_format_fn.call(i))
    end
    str
  end

  def MultiMonitorUtils::build_formatter(base_format_fn)
    build_format_str(base_format_fn, get_num_monitors)
  end
end
