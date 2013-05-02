module Cardboard
  class Field::Decimal < Field
    validates :value, :numericality  => { :only_integer => false }, :allow_nil => true
    validates :value, presence:true, :if => :required_field?


    def value
      super.to_f
    end

    def default
      234.23
    end

  end
end