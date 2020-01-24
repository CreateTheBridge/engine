require 'algoliasearch'

module Locomotive
  module Concerns
    module AlgoliaService
      STATIC_FIELDS = %w(seo_title meta_description meta_keywords created_at updated_at _position _visible _translated)


      def algolia_client
        @algolia_client ||= Algolia.init(application_id: Locomotive.config[:algolia][:app_id], api_key: Locomotive.config[:algolia][:api_key])
        @algolia_client
      end

      def serializable_fields(content_entry)
        content_entry.custom_fields_recipe["rules"].map{|rule|
          {
            name: rule["name"],
            data_type: rule["type"],
            options: rule["select_options"]
          }
        }
      end

      def serialize_object(content_entry, process_relationships = true)
        ## Get base fields present on every ContentEntry
        result = { objectID: content_entry._slug }
        result = result.merge(content_entry.to_steam.to_hash.slice(STATIC_FIELDS))

        ## Build the serializable fields list
        fields = serializable_fields(content_entry)
        relationships = fields.select{|x| %w(many_to_many belongs_to has_many).include?(x[:data_type]) }.map{|y| y[:name]}

        ## Loop the serializable fields and add the data to the results
        content_hash = content_entry.as_json

        fields.each do |field|
          if %w(many_to_many belongs_to has_many).include?(field[:data_type]) and process_relationships # Relationship

            result[field[:name]] = add_relationships_to_serialized_object(field, content_entry)

          elsif field[:data_type] == "select"
            selected_value = content_entry.send(field[:name].to_sym)
            if selected_value.nil?
              selected_id = content_entry.send("#{field[:name]}_id".to_sym)
              selected_option = field[:options].select{|option| return selected_id == option["_id"] }.first
              result[field[:name]] = selected_option["name"] if selected_option.present?
            else
              result[field[:name]] = selected_value
            end
          else

            result[field[:name]] = content_hash[field[:name]]

          end
        end

        return result
      end

      def add_relationships_to_serialized_object(field, content_entry)
        items = content_entry.send(field[:name].to_sym)
        if items.is_a? Array
          return items.map{|item| serialize_object(item, false) }
        else
          return serialize_object(items, false)
        end
      end

      def add_to_algolia(content_entry)
        return unless content_entry.content_type.algolia_indexing_enabled

        algolia_client
        index = Algolia::Index.new("#{content_entry.content_type.slug}--#{content_entry.site.handle}")
        result = serialize_object(content_entry)
        puts JSON.pretty_generate(result)
        index.save_object(result)
      end

      def remove_from_algolia(content_entry)
        return unless content_entry.content_type.algolia_indexing_enabled

        algolia_client
        index = Algolia::Index.new(content_entry.content_type.slug)
        index.delete_object(content_entry._slug)
      end

    end
  end
end
