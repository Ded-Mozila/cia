module CIA
  module Auditable
    def self.included(base)
      base.class_attribute :audited_attributes, :audited_attribute_options, :audited_attributes_callbacks_added
      base.send :extend, ClassMethods
    end

    def cia_changes
      changes
    end

    def cia_previous_changes(changes=nil)
      if changes
        @cia_previous_changes = changes
      else
        old, @cia_previous_changes = @cia_previous_changes, nil
        old
      end
    end

    module ClassMethods
      def audit_attribute(*attributes)
        options = (attributes.last.is_a?(Hash) ? attributes.pop : {})
        setup_auditing_callbacks(options)

        self.audited_attributes = attributes.map(&:to_s)

        raise "cannot have :if and :unless" if options[:if] && options[:unless]
        self.audited_attribute_options = options

        has_many :cia_events, :class_name => "CIA::Event", :as => :source
        has_many :cia_attribute_changes, :class_name => "CIA::AttributeChange", :as => :source
      end

      def setup_auditing_callbacks(options)
        return if audited_attributes_callbacks_added
        self.audited_attributes_callbacks_added = true

        [:create, :update, :destroy].each do |callback|
          method, args = if options[:callback] == :after_commit
            send("after_#{callback}"){ |record| record.cia_previous_changes(record.cia_changes) }
            if ActiveRecord::VERSION::MAJOR == 2
              ["after_commit_on_#{callback}", []]
            else # rails 3+
              [:after_commit, [{:on => callback}]]
            end
          else
            ["after_#{callback}", []]
          end
          send(method, *args) { |record| CIA.record(callback, record) }
        end
      end
    end
  end
end
