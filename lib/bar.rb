class LemonBar
  def initialize(bar_config, lemonbar_format)
    @bar_config = bar_config
    @lemonbar_format = lemonbar_format
  end

  def layer
    Thread.new do
      sleep 1
      panel_ids = `xdo id -a bspwm-panel`
      puts "panel ids = #{panel_ids}"
      root_ids = `xdo id -n root`
      panel_ids.each_line do |pid|
        root_ids.each_line do |rid|
          system("xdo below -t #{rid.chomp} #{pid.chomp}")
        end
      end
      panel_ids.each_line do |pid|
        root_ids.each_line do |rid|
          system("xdo above -t #{rid.chomp} #{pid.chomp}")
        end
      end
    end
  end

  def run
    lemonbar_command = "lemonbar -a 32 -n #{@bar_config.settings[:wm_name]} -g x#{@bar_config.settings[:bar_height]}"\
      " -f \"#{@bar_config.settings[:bar_font]}\" -F \"#{@bar_config.colours[:DEFAULT_FG]}\""\
      " -B \"#{@bar_config.colours[:DEFAULT_BG]}\""
    formatter_read, formatter_write = IO.pipe
    lemon_pipe = IO.popen(lemonbar_command, 'r+')
    button_shell_pipe = IO.popen('sh', 'w')

    @lemonbar_format.set_pipe(formatter_write)
    @lemonbar_format.run_bar
    layer
    Thread.new do
      formatter_read.each_line do |line|
        lemon_pipe.puts line
      end
    end

    Thread.new do
      lemon_pipe.each_line do |line|
        button_shell_pipe.puts line
      end
    end
    sleep
  end
end
