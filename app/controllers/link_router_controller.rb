# All clicks on a ServiceResponse are actually sent through this controller,
# which redirects to actual destination. That allows statistic logging,
# as well as special behavior (like EZProxy redirection, or showing in a
# bannered frameset). 
require 'cgi'
class LinkRouterController < ApplicationController
  # Will be redirected to a bannered frameset link based on the value
  # of app config "link_with_frameset".  URL parameter
  # "umlaut.link_with_frameset=false" can suppress that.
  # See environment.rb-dist for instructions on setting
  # app parameter. .
  def index

    # Capture mysterious exception for better error reporting. 
    begin
      svc_type = ServiceType.find(params[:id])
    rescue ActiveRecord::RecordNotFound => exception
      # Usually this happens when it's a spider trying an old link. "go" links
      # don't stay good forever! Bad spider, ignoring our robots.txt.
      
      logger.warn("LinkRouter/index not found exception!: #{exception}\nReferrer: #{request.referer}\nUser-Agent:#{request.user_agent}\nClient IP:#{request.remote_addr}\n\n")

      error_404
      return            
    end


    @collection = Collection.new(svc_type.request, session)          

    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_type.request_id
    clickthrough.service_response_id = svc_type.service_response_id
    clickthrough.save

    if ( link_with_frameset?(svc_type) )
      redirect_to( frameset_action_url(svc_type) )
    else
      url = calculate_url_for_response(svc_type)      
      redirect_to url
    end
  end

    
  protected
  # Should a link be displayed inside our banner frameset?
  # Depends on config settings, url params, and 
  # whether the resolve menu was skipped or not.
  def link_with_frameset?( svc_type)
    # Over-ridden in url?
    if ( params['umlaut.link_with_frameset'] == 'false' )
      return false
    elsif ( params['umlaut.link_with_frameset'] == 'true')
      return true
    end

    # Otherwise load from app config
    config = AppConfig.param("link_with_frameset", :standard) if config.nil?
    
    case config
      when TrueClass
        return true
      when FalseClass
        return false
      when :standard
        # 'Standard' behavior is frameset link only if we're coming
        # from a menu-skip, which is indicated with a URL param. 
        return params[:'umlaut.skipped_menu'] == true
      when Proc
        # Custom defined logic
        return config.call( :service_type_join => svc_type )
      else
        logger.error( "Unexpected value in app config 'link_with_frameset'; assuming false." )
        return false
      end    
  end

   
end
