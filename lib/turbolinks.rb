module Turbolinks
  module XHRHeaders
    extend ActiveSupport::Concern

    included do
      alias_method_chain :_compute_redirect_to_location, :xhr_referer
    end

    private
      def _compute_redirect_to_location_with_xhr_referer(options)
        store_for_turbolinks begin
          if options == :back && request.headers["X-XHR-Referer"]
            _compute_redirect_to_location_without_xhr_referer(request.headers["X-XHR-Referer"])
          else
            _compute_redirect_to_location_without_xhr_referer(options)
          end
        end
      end

      def store_for_turbolinks(url)
        session[:_turbolinks_redirect_to] = url if request.headers["X-XHR-Referer"]
        url
      end

      def set_xhr_redirected_to
        if session[:_turbolinks_redirect_to]
          response.headers['X-XHR-Redirected-To'] = session.delete :_turbolinks_redirect_to
        end
      end
  end

  module Cookies
    private
      def set_request_method_cookie
        cookies[:request_method] = request.request_method
      end
  end

  module XDomainBlocker
    private
    def same_origin?(a, b)
      a = URI.parse URI.escape(a)
      b = URI.parse URI.escape(b)
      [a.scheme, a.host, a.port] == [b.scheme, b.host, b.port]
    end

    def abort_xdomain_redirect
      to_uri = response.headers['Location'] || ""
      current = request.headers['X-XHR-Referer'] || ""
      unless to_uri.blank? || current.blank? || same_origin?(current, to_uri)
        self.status = 403
      end
    end
  end

  module Redirection
    extend ActiveSupport::Concern
    
    def redirect_via_turbolinks_to(url = {}, response_status = {})
      redirect_to(url, response_status)

      self.status           = 200
      self.response_body    = "Turbolinks.visit('#{location}');"
      response.content_type = Mime::JS
    end
  end

  class Engine < ::Rails::Engine
    initializer :turbolinks_xhr_headers do |config|
      ActionController::Base.class_eval do
        include XHRHeaders, Cookies, XDomainBlocker, Redirection
        before_filter :set_xhr_redirected_to, :set_request_method_cookie
        after_filter :abort_xdomain_redirect
      end

      ActionDispatch::Request.class_eval do
        def referer
          self.headers['X-XHR-Referer'] || super
        end
        alias referrer referer
      end
    end
  end
end
