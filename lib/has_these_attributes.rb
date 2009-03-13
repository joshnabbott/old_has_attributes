# TODO: write specs
module HasTheseAttributes
  # Mix below class methods into ActiveRecord.
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
  end

  # Class methods to mix into active record.
  module ClassMethods # :nodoc:
    def has_these_attributes(*attributes)
      return if self.included_modules.include?(InstanceMethods)
      # Hack for the *_attribute table doesn't exist.
      return unless eval("#{name}Attribute").table_exists?
      send(:include, InstanceMethods)
      @@_attributes = attributes
      validate_these_attributes
      after_update :save_localized_attributes
      has_many :"#{name.downcase}_attributes", :dependent => :destroy
      has_one :"#{name.downcase}_attribute", :conditions => 'locale_id = #{Locale.current_locale_id}'
      eval_methods_in_association_class("#{name}Attribute")
      attributes.each do |attr|
        delegate_to_nil :"#{attr}", :to => :"#{self.name.downcase}_attribute"
      end
    end

    def _attributes
      @@_attributes
    end

    def eval_methods_in_association_class(klass)
      klass.constantize.class_eval <<-EOV
        attr_protected :locale_id
        before_save :set_locale_id, :if => Proc.new { |record| record.domain_id.nil? }
        protected
          def set_locale_id
            self.domain_id = Locale.current_locale_id
          end
      EOV
    end

  protected
    def validate_these_attributes
      valid_attributes = "#{name}Attribute".constantize.columns.map(&:name)
      @@_attributes.each do |attr|
        raise ActiveRecord::UnknownAttributeError, "unknown attribute: #{attr}" unless valid_attributes.include?("#{attr}")
      end
    end
  end # ClassMethods

  # Instance methods to mix into ActiveRecord.
  module InstanceMethods #:nodoc:
    def _attributes
      self.class._attributes
    end

    # def attributes
    #   # include pseudo attributes in @instance.attributes
    #   real_attributes = super
    #   real_attributes.reverse_merge!(params_for_save).stringify_keys!
    # end

  private
    def _attributes_plural_name
      "#{self.class.name.downcase}_attributes"
    end

    def _attributes_singular_name
      "#{self.class.name.downcase}_attribute"
    end

    def params_for_save
      _attributes.inject({}) do |attrs,name|
        attrs[name] = send("#{name}")
        attrs
      end
    end

    def save_localized_attributes
      send(_attributes_singular_name).save! if send(_attributes_singular_name) && send(_attributes_singular_name).changed?
    end
  end # InstanceMethods
end # HasTheseAttributes