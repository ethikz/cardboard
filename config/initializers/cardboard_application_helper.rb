# module Cardboard
#   module UrlHelper
#     def method_missing(method, *args, &block)
#       if params[:controller] == "cardboard/pages" && ["index","show"].include?(params[:action]) && (method.to_s.end_with?('_path') || method.to_s.end_with?('_url')) && main_app.respond_to?(method)
#         main_app.send(method, *args)
#       else
#         super
#       end
#     end
#   end
# end

# ActionController::Base.send(:helper, Cardboard::UrlHelper)