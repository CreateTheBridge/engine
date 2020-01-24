require 'algoliasearch'

module Locomotive
  module Concerns
    module AlgoliaService

      def algolia_client
        @algolia_client ||= Algolia.init(application_id: Locomotive.config[:algolia][:app_id], api_key: Locomotive.config[:algolia][:api_key])
        @algolia_client
      end

      def algolia_fields(content_entry)
        content_entry.custom_fields_recipe["rules"].map{|rule|
          {
            name: rule["name"],
            data_type: rule["type"],
            options: rule["select_options"]
          }
        }
      end

      def add_to_algolia(content_entry)
        return unless content_entry.content_type.algolia_indexing_enabled

        algolia_client
        index = Algolia::Index.new("#{content_entry.content_type.slug}--#{content_entry.site.handle}")

        fields = algolia_fields(content_entry)

        obj = {
          objectID: content_entry._slug,
          sort_position: content_entry._position
        }

        obj = obj.merge(content_entry.to_steam.to_hash.slice(
          "seo_title",
          "meta_description",
          "meta_keywords",
          "created_at",
          "updated_at",
          "_visible",
          "_translated"
        ))

        tmp = content_entry.as_json

        fields.each do |field|
          if field[:data_type] == "select"
            option = field[:options].select{|x| x["_id"].to_s == tmp["#{field[:name]}_id"]}

            puts option
            if option.any?
              obj["#{field[:name]}_id"] = tmp["#{field[:name]}_id"]
              obj[field[:name]] = option[0]["name"]
            else
              obj["#{field[:name]}_id"] = tmp["#{field[:name]}_id"]
            end
          else
            obj[field[:name]] = tmp[field[:name]]
          end
        end

        puts ""
        puts obj
        puts ""

        index.save_object(obj)
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
