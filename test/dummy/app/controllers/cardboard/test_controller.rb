require_dependency Cardboard::Engine.root.join('app', 'controllers', 'cardboard', 'admin_controller')
module Cardboard
  class TestController < AdminController
    inherit_resources
    def index
    end
  end
end