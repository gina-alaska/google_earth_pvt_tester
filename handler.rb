#
# Web serving related happyness... And it seems like tommarrow might not come...
# provides a way to mail errors etc..
require 'cgi'

# ************************************************************************************************

##
# Base class, don't instatuate, use sub-classes..
class RackWelder
  # constants for headers.  Rack should have these, perhaps it does and I am stupid.
  ETAG_FORMAT = "\"%x-%x-%x\""
  HTTP_IF_MODIFIED_SINCE = 'HTTP_IF_MODIFIED_SINCE'
  HTTP_IF_NONE_MATCH = 'HTTP_IF_NONE_MATCH'
  ETAG  = 'ETag'
  CONTENT_TYPE = 'Content-Type'
  CONTENT_LENGTH = 'Content-Length'
  LAST_MODIFIED = 'Last-Modified'

  ##
  # Stub to be used for driving directly by rack, mainly for testing. Not for real use.
  def call(env)
    request = Rack::Request.new(env)
    response = Rack::Response.new
    process(request, response)
    [response.status, response.headers, response.body]
  end

  private

  # General purpose out to http function..
  def give_X(response, status, mime_type, msg)
    response.status = status
    response.body = [msg]
    response.headers['Content-Type'] = mime_type
    response.headers[CONTENT_LENGTH] = response.body.join.length.to_s
  end

  ###
  # General purpose out to http function..
  def give_301(response, url)
    response.status = 301
    response.headers['Location'] = url
  end

  ###
  # Send out a 404 error, used to give a simple/quick error to usr
  def give404(response, msg)
    give_X(response, 404, 'plain/text', msg)
  end
end
