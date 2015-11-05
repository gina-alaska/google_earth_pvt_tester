###
# A very basic controller handler that allows
# restarting and reloading on the fly..
require_relative 'render'
class ControllerHandler < RackWelder
  def initialize(log, cfg, roundhouse)
    @logger = log
    @REMOTE_IP_TAG = 'HTTP_X_FORWARDED_FOR'
    @cfg = cfg # cfg..

    setup_access_list(cfg['controller'])
    @roundhouse = roundhouse
  end

  def process(request, response)
    ip = request.env[@REMOTE_IP_TAG]
    ip = '0.0.0.0' unless ip

    unless allowed(ip)
      give_X(response,
             403,
             'text/plain',
             "Access from #{ip} is not allowed. Go Away.")
      return
    end

    action = request.env['PATH_INFO'].split('/').last
    @logger.msginfo("Controller: Recieved action '#{action}'")
    case (action)
    when @cfg['controller']['reload_action']
      reload(request, response)
    else
      give_X(response,
             404,
             'text/plain',
             "'#{request.env['PATH_INFO']}' is not a valid controller url..")
    end
  end

  private

  ##
  # Handles a reload request..
  def reload(_request, response)
    @roundhouse.load(@cfg)
    give_X(response, 200, 'text/plain', 'Reloading..')
  end

  ##
  # turns a string ip (xxx.xxx.xxx.xxx ) to a number set..
  def ip_to_nip(ip)
    nip = []
    ip.split('.').each { |x| nip << x.to_i }
    nip
  end

  ##
  # checks to see if a_ip == b_ip..
  def nip_test(a_ip, b_ip)
    0.upto(3) { |x| return false if (a_ip[x] != b_ip[x]) }
    true
  end

  ##
  # sets up the allowed ip list..
  def setup_access_list(_cfg)
    @access_list = []
    @cfg['controller']['ips_allowed'].each do |ip|
      @access_list << ip_to_nip(ip)
    end
  end

  ##
  # checks to see if x is allowed..
  def allowed(ip)
    nip = ip_to_nip(ip)
    @access_list.each do |x_ip|
      return true if nip_test(nip, x_ip)
    end
    false
  end
end

#########
# Base class for controller bits.
class ControlPanelBase < RackWelder
  # set stuff up, log=logger, cfg=shiv kml config.
  def initialize(log, cfg, list)
    @logger = log

    # save the config..
    @cfg = cfg

    # save the tilers items
    @list = list

    # save the root url.
    @url_root = @cfg['root_url']

    @render = RenderEng.new
  end

  private

  # handles errors - override error_msg to add a different msg
  def handle_error(excpt, request, response)
    ###
    # Ok, something very bad happend here... what to do..
    # send_file_full(@cfg["error"]["img"],request,response,@cfg["error"]["format"])
    stuff = "Broken at #{Time.now.to_s}"
    stuff += "--------------------------\n"
    stuff += excpt.to_s + "\n"
    stuff += "--------------------------\n"
    stuff += excpt.backtrace.join("\n")
    stuff += "--------------------------\n"
    stuff += "request => " + YAML.dump(request)+ "\n-------\n"
    error_msg(response, 'A problem has occured..')
    @logger.logerr("Crash in::#{@lt}" + stuff)
  end

  def error_msg(response, msg)
    give_X(response, 500, 'text/plain', msg)
  end

  def remove_root(path)
    path[@cfg['http']['base'].length, path.length]
  end

  def path_to_chunks(path)
    bits = remove_root(path).split(/\/+/)
    bits.delete_at(0)
    bits
  end

  def get_tile_config(item)
    @list.each { |x| return x if (item == x['title']) }
  end

  def get_tile_layout(item)
    cfg = get_tile_config(item)
    return 'map_layout' if !cfg['view'] || !cfg['view']['layout']
    cfg['view']['layout']
  end
end

# ControlPanel
# handles ->
# / -> give index
# /info -> give details
class ControlPanel < ControlPanelBase
  # set stuff up, log=logger, cfg=shiv kml config.
  def initialize(log, cfg, list)
    super(log, cfg, list)
  end

  # Do something..
  def process(request, response)
    path = path_to_chunks(request.path)
    puts path.join(':')
    case path.first
    when nil then give_X(response, 200, 'text/html', @render.render('index', @list, 'index_layout'))
    when 'info'
      if path[1].nil?
        give_X(response, 404, 'text/html', 'Bad URL.')
      else
        give_X(response, 200, 'text/html', @render.render('info', get_tile_config(path[1])))
      end
    else error_msg(response, 'Got nothing..')
    end
    return
  rescue => excpt
    handle_error(excpt, request, response)
  end
end
