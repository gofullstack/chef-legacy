require 'supermarket/community_site/pool'

module Supermarket
  module CommunitySite
    #
    # A sad, but adequate ORM for the existing Opscode Community Site
    #
    module SadequateRecord
      #
      # Exposes a +fields+ macro which sets up +attr_accessor+s and an
      # attribute-based constructor.
      #
      # @example
      #   class UserRecord
      #     extend SadequateRecord::Record
      #
      #     fields :id
      #   end
      #
      #   record = UserRecord.new(id: 1)
      #   record.id #=> 1
      #
      module Record
        def fields(*fields)
          fields.each do |field|
            send(:attr_accessor, field.to_sym)
          end

          define_singleton_method(:sadequate_fields) { fields }

          define_method(:initialize) do |data = {}|
            data.select do |field, _|
              fields.map(&:intern).include?(field.intern)
            end.each do |field, value|
              instance_variable_set("@#{field}", value)
            end
          end
        end
      end

      #
      # Provides a single class macro, +has_many+ which is way less powerful
      # than ActiveRecord's. I'd say it's "sadequate"
      #
      # @example
      #
      # class User
      #   extend SadequateRecord::HasMany
      #
      #   has_many :posts, PostRecord, :user_id
      # end
      #
      # user = User.new
      # user.posts #=> [#<PostRecord...>]
      #
      module HasMany
        def has_many(collection, record_type, foreign_key)
          define_method(collection) do
            real_record_type = Supermarket::CommunitySite.const_get(record_type)

            fields = real_record_type.sadequate_fields.join(', ')

            query_template = %{
              SELECT %s FROM #{collection}
              WHERE #{foreign_key} = %d ORDER BY id
            }.squish

            Pool.with do |connection|
              connection.query(query_template % [fields, id]).to_a
            end.map do |record_data|
              real_record_type.new(record_data)
            end
          end
        end
      end

      #
      # Provides a single class macro, +belongs_to+ which is way less powerful
      # than ActiveRecord's.
      #
      # @example
      #
      # class Post
      #   extend SadequateRecord::BelongsTo
      #
      #   belongs_to :user, UserRecord, :user_id
      # end
      #
      # post = Post.new
      # post.user #=> #<UserRecord...>
      #
      module BelongsTo
        def belongs_to(name, record_type, foreign_key)
          define_method(name) do
            real_record_type = Supermarket::CommunitySite.const_get(record_type)

            fields = real_record_type.sadequate_fields.join(', ')

            query_template = %{
              SELECT %s FROM #{real_record_type.sadequate_table_name}
              WHERE id = %d
            }.squish

            record_data = Pool.with do |connection|
              connection.query(query_template % [fields, send(foreign_key)]).to_a
            end.first

            if record_data
              real_record_type.new(record_data)
            end
          end
        end
      end

      #
      # Provides a single class macro, +table+ which is sort of like inheriting
      # from ActiveRecord::Base. It makes instances of the class +Enumerable+
      # over the given table's records. The primary assumption is that the
      # table has an +id+ column which increases monotonically
      #
      # @example
      #   class UserTable
      #     extend SadequateRecord::Table
      #
      #     table :users, UserRecord
      #   end
      #
      #   user_table = UserTable.new
      #   user_table.count #=> 100
      #
      module Table
        def table(name, record_type)
          define_method(:sadequate_table_name) do
            name
          end

          define_method(:record_at_offset) do |offset|
            real_record_type = Supermarket::CommunitySite.const_get(record_type)

            query = "SELECT %s FROM #{name} ORDER BY id LIMIT 1 OFFSET %d"
            offset_query = query % [
              real_record_type.sadequate_fields.join(', '),
              offset
            ]

            Pool.with do |connection|
              connection.query(offset_query).to_a.first
            end
          end

          define_method(:each) do |&block|
            real_record_type = Supermarket::CommunitySite.const_get(record_type)

            offset = 0

            while data = record_at_offset(offset)
              offset += 1
              block.call(real_record_type.new(data))
            end
          end

          define_method(:count) do
            query = "SELECT COUNT(*) as cnt FROM #{name}"

            Pool.with do |connection|
              connection.query(query).to_a.first['cnt']
            end
          end

          include Enumerable
        end
      end
    end
  end
end
