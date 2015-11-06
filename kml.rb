require 'cgi'
require 'xmlsimple'
require 'yaml'

##
# Serves up kml..
class KMLHandler < RackWelder
  # set stuff up, log=logger, cfg=shiv kml config.
  def initialize(log, http_conf, set, cfg)
    @logger = log

    # the ip of the requesting host..
    @REMOTE_IP_TAG = 'HTTP_X_FORWARDED_FOR'

    # save the config..
    @cfg = {
      'set' => set,
      'source' =>  'http://' +  http_conf['host'] + http_conf['base'] + '/' + set + '/bbox/%.20f/%.20f/%.20f/%.20f/',
      'url' => "http://" + http_conf['host'] + http_conf['base'] + '/' + '%s/kml/%.20f/%.20f/%.20f/%.20f/',
      'cfg' => cfg
    }

    # save the root url.
  end

  # get url - returns the url for a bounding box
  def get_wms_url(bbox)
    sprintf('%s?layers=%s&service=WMS&format=%s&width=%d&request=GetMap&height=%d&srs=EPSG:4326&version=1.1.1&bbox=%6.10f,%6.10f,%6.10f,%6.10f',
            @cfg['cfg']['source_url'],
            @cfg['cfg']['layers'],
	     @cfg['cfg']['format'],
            @cfg['cfg']['tiles']['x_size'],
            @cfg['cfg']['tiles']['y_size'],
            bbox['x_min'], bbox['y_min'], bbox['x_max'], bbox['y_max'])
  end

  # Do something..
  def process(request, response)
    @logger.puts("KML -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params['REQUEST_URI']}")

    uri = request.env['PATH_INFO']
    if  uri.nil?
      give404(response, 'Try a real url, thats not nil.')
      return
    else
      # uri should be for the form something/set/kml/lt_x/tl_y/br_x/br_y
      uri = uri.split('/')
      #remove last item if not a number = used to detect if a /sfsd/foo.kml
      #type thing is added and remove it.
      uri.delete_at(-1) if !(/^[-+]?[0-9]+[.]?[0-9]*([eE][-+]?[0-9]+)?$/ =~ uri.last )
      puts uri.join("::")


      if (uri.length <= 6)
        give404(response, 'Try a real url, perhaps one that is valid and of the form /set/lt_x/tl_y/br_x/br_y')
        return
      end

      set = uri[-6]
      tl_x = uri[-4].to_f
      tl_y = uri[-3].to_f
      br_x = uri[-2].to_f
      br_y = uri[-1].to_f

      if (set != @cfg['set'])
        give404(response, "Try a real url, perhaps one that is valid and of the form /set/lt_x/tl_y/br_x/br_y where set is \"#{@cfg['set']}\" not \"#{set}\"")
        return
      end

      ##
      # This is the case if things are really broken - possibly not possible now..
      # Not sure if the behavior is good, or bad -  should possibly just generate an error now..
      if  br_x.nil? || br_y.nil? || tl_x.nil? || tl_y.nil? || set.nil?
        give404(response, 'Try a real url, perhaps one that is valid and of the form /set/kml/lt_x/tl_y/br_x/br_y')
        return
      end

      response.status = 200
      response.header['Content-Type'] = 'application/vnd.google-earth.kml+xml'
      @logger.msgdebug('KMLHandler:process:' + sprintf('(%g,%g) -> (%g,%g)', br_x.to_f, br_y.to_f, tl_x.to_f, tl_y.to_f))
      stuff = do_level(@cfg, set, tl_x.to_f, tl_y.to_f, br_x.to_f, br_y.to_f)
      response.write(stuff)
    end
  rescue => excpt
    ###
    # Ok, something very bad happend here... what to do..
    stuff = "Broken at #{Time.now}"
    stuff += "--------------------------\n"
    stuff += excpt.to_s + "\n"
    stuff += "--------------------------\n"
    stuff += excpt.backtrace.join("\n")
    stuff += "--------------------------\n"
    stuff += 'request => ' + YAML.dump(request) + "\n-------\n"
    @logger.logerr("Crash in::#{@lt}" + stuff)
  end

  # generates a url to the new down level
  def url_to_lower_level(hcfg, set, tl_x, tl_y, br_x, br_y)
    @logger.msgdebug('KMLHandler:url_to_lower_level:' + sprintf('url_to_lower_level(%g,%g) -> (%g,%g)', br_x.to_f, br_y.to_f, tl_x.to_f, tl_y.to_f))
    sprintf(hcfg['url'], set, tl_x, tl_y, br_x, br_y)
  end

  # url to actual image..
  def url_to_img(_hcfg, _set, tl_x, tl_y, br_x, br_y)
    get_wms_url('x_min' =>  tl_x.to_f, 'x_max' => br_x.to_f, 'y_min' => br_y.to_f, 'y_max' =>  tl_y.to_f)
  end

  # Generates a bounding box google kml style

  def hshtoLatLonAltBox(cfg, set, tl_x, tl_y, br_x, br_y, note)
    maxlodpixels = -1
    @logger.msgdebug('KMLHandler:hshtoLatLonAltBox:' + sprintf('((br_x - tl_x))=>%g (%s)', (br_x - tl_x), note))

    # Old Lod
    #  "Lod"=>[ {"maxLodPixels"=>["#{maxlodpixels}"], "minLodPixels"=>["128"],  "minFadeExtent"=>["128"],  "maxFadeExtent"=>["128"]}],
    {
      'name' => [sprintf('%s_%.20f_%.20f_%.20f_%.20f%', set, tl_x, tl_y, br_x, br_y)],
      'Region' =>           [
        {
          'Lod' => [{ 'maxLodPixels' => ["#{maxlodpixels}"], 'minLodPixels' => ["128"] }],
          'LatLonAltBox' =>                 [{
            'east' => ["#{br_x}"],
            'south' => ["#{br_y}"],
            'west' => ["#{tl_x}"],
            'north' => ["#{tl_y}"]
          }]
        }
      ],
      'Link' =>           [{
        'href' => [url_to_lower_level(cfg, set, tl_x, tl_y, br_x, br_y)],
        'viewRefreshMode' => ['onRegion']
      }]
    }
  end

  # generates a kml file for tl,br
  def do_level(cfg, set, tl_x, tl_y, br_x, br_y)
    w = br_x -  tl_x
    h = tl_y -  br_y
    w /= 2.0
    h /= 2.0

    maxlodpixels = 1024
    # maxlodpixels = 680
    # maxlodpixels = -1 if ((  br_x - tl_x   > 5 ))

    networklink = []

    ##
    # Zoom level 24 is the limit...

    0.upto(1) do |x|
      0.upto(1) do |y|
        networklink += [hshtoLatLonAltBox(cfg, set, tl_x + w * x,     br_y + h * (y + 1),    tl_x + w * (x + 1),     br_y + h * (y),    'tl')]
      end
    end

    # Draw order stuff..
    # "drawOrder"=>["#{((1.0/w)*180).to_i}"]
    hsh = { 'Document' =>   	[
      {
        'name' => [sprintf('%s_%.20f_%.20f_%.20f_%.20f%d', set, tl_x, tl_y, br_x, br_y, rand(32_000))],
        'NetworkLink' => networklink,
        'GroundOverlay' =>              [
          {
            'LatLonBox' =>                  [
              {
                'east' => ["#{br_x}"],
                'south' => ["#{br_y}"],
                'west' => ["#{tl_x}"],
                'north' => ["#{tl_y}"]
              }
            ],
            'Icon' => [
              {
                'href' => ["#{url_to_img(cfg, set, tl_x, tl_y, br_x, br_y)}"]
              }
            ],
            'drawOrder' => ["#{((1.0 / w) * 180 + 1000).to_i}"]
          }
        ],
        'Region' =>     [
          {
            'Lod' => [{ 'maxLodPixels' => ["#{maxlodpixels}"], 'minLodPixels' => ["124"] }],
            'LatLonAltBox' =>               [{
              'east' => ["#{br_x}"],
              'south' => ["#{br_y}"],
              'west' => ["#{tl_x}"],
              'north' => ["#{tl_y}"]
            }]
          }
        ]
      }
    ],
            'xmlns' => 'http://earth.google.com/kml/2.1'
    }

    (XmlSimple.xml_out(hsh,  {'rootname' => 'kml', "NoEscape"=>false}))
  end
end

class XYZMapper
  def initialize(cfg, logger)
    @cfg = cfg
    @log = logger

    @x_count = cfg['tiles']['x_count']
    @y_count = cfg['tiles']['y_count']
  end

  ##
  # Note -> z level = log(width of world / width of request)/log(2)
  # takes a bbox, returns the tile that it repersents..
  # Todo: Handle case where things to not match..
  def min_max_to_xyz(min_x, min_y, max_x, max_y)
    @log.loginfo("TileEngine:min_max_to_xyz (#{min_x},#{min_y},#{max_x}, #{max_y})..")
    dx = max_x - min_x
    dy = max_y - min_y

    zx = Math.log((@cfg['base_extents']['xmax'] - @cfg['base_extents']['xmin']) / dx) / Math.log(2)
    zy = Math.log((@cfg['base_extents']['ymax'] - @cfg['base_extents']['ymin']) / dy) / Math.log(2)

    x = (min_x - @cfg['base_extents']['xmin']) / dx
    y = (min_y - @cfg['base_extents']['ymin']) / dy

    x = x.to_i
    y = y.to_i

    @log.msgdebug("TileEngine:min_max_to_xyz:zlevels.. (#{zx},#{zy})..")

    @log.msgdebug("TileEngine:min_max_to_xyz:results (#{x},#{y},#{zx})..")
    [x, y, zx.to_i]
  end

  # maps x,y,z tile to map projection x/y/min/max
  def x_y_z_to_map_x_y(x, y, z)
    w_x = (@cfg['base_extents']['xmax'] - @cfg['base_extents']['xmin']) / (2.0**(z.to_f))
    w_y = (@cfg['base_extents']['ymax'] - @cfg['base_extents']['ymin']) / (2.0**(z.to_f))
    x_min = @cfg['base_extents']['xmin'] + x * w_x
    { 'x_min' => @cfg['base_extents']['xmin'] + x * w_x,
      'y_min' => @cfg['base_extents']['ymin'] + y * w_y,
      'x_max' => @cfg['base_extents']['xmin'] + (x + 1) * w_x,
      'y_max' => @cfg['base_extents']['ymin'] + (y + 1) * w_y }
  end

  def  x_y_z_to_map_x_y_enlarged(x, y, z, x_count, y_count)
    x_y_z_to_map_x_y(x + x_count - 1, y + y_count - 1, z)
  end

  def single?(x, y, z)
    side = 2**z
    return true if  (x > side - @x_count) || y > side - @y_count
    false
  end

  def valid?(x, y, z)
    false if x > (2**(z + 1)) || y > (2**(z + 1)) || z > 24
    true
  end

  def up?
    true
  end

  def max_x(z)
    2**z
  end

  def max_y(z)
    2**z
  end
end
