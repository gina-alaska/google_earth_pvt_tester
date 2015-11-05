
# very basic logging class
class Lumber
  # basic rules
  # debug - stuff only of interest to debugging, on if @debug
  # info - noisy stuff, on if not quiet
  # error - always on

  def initialize(cfg)
    @cfg = cfg

    ##
    # Defaults
    @debug = false
    @info = false
    @quiet = false
    @verbose = false

    @verbose = true if cfg['verbose']
    @info = true if cfg['info']
    @quiet = true if cfg['quiet']
    @debug = true if cfg['debug']

    msgerror('Start.')
    msginfo('Logging Started.')
  end

  def msginfo(s)
    return if @quiet
    return unless @verbose
    format_for_output(@info_fd, 'INFO', s)
    format_for_output(STDOUT, 'INFO', s)
  end

  def loginfo(s)
    msginfo(s)
  end

  def msgdebug(s)
    return if  !@debug || @quiet
    format_for_output(@info_fd, 'DEBUG', s)
    format_for_output(STDOUT, 'DEBUG', s)
    format_for_output(@debug_fd, 'DEBUG', s)
  end

  def msgstatus(s)
    return if  !@verbose || @quiet
    format_for_output(STDOUT, 'STATUS', s)
  end

  def logstatus(s)
    msgstatus(s)
  end

  def msgerror(s)
    format_for_output(@info_fd, 'ERROR', s)
    format_for_output(@error_fd, 'ERROR', s)
    format_for_output(STDERR, 'ERROR', s)
  end

  def logerr(s)
    msgerror(s)
  end

  def puts(s)
    msgstatus(s)
  end

  private

  def format_for_output(out, label, s)
    out.write(sprintf("(%s:%s) %s\n", time, label, s))
  end

  def time
    Time.now.utc.strftime('%Y/%m/%d %H:%M:%S')
  end
end

##
# Stub class, only logs to stdout..
class LumberNoFile < Lumber
  # basic rules
  # debug - stuff only of interest to debugging, on if @debug
  # info - noisy stuff, on if not quiet
  # error - always on

  def initialize(cfg)
    @error_fd = STDOUT
    @debug_fd = STDOUT
    @info_fd = STDOUT
    super(cfg)
  end

  def log_xfer(_request, _response, _size, _tm)
    # nothing
  end

  def log_access(_request)
    # nothing..
  end
end
