require 'hanami/utils/basic_object'
require 'hanami/utils/string'
require 'hanami/utils/blank'

module Hanami
  module Model
    module Adapters
      # It's raised when an adapter can't find the underlying database adapter.
      #
      # Example: When we try to use the SqlAdapter with a Postgres database
      # but we didn't loaded the pg gem before.
      #
      # @see Hanami::Model::Adapters::SqlAdapter#initialize
      #
      # @since 0.1.0
      class DatabaseAdapterNotFound < Hanami::Model::Error
      end

      # It's raised when an adapter does not support a feature.
      #
      # Example: When we try to get a connection string for the current database
      # but the adapter has not implemented it.
      #
      # @see Hanami::Model::Adapters::Abstract#connection_string
      #
      # @since 0.3.0
      class NotSupportedError < Hanami::Model::Error
      end

      # It's raised when a URI is nil or empty
      #
      # @since x.x.x
      class MissingURIError < Hanami::Model::Error
        def initialize(adapter_name)
          super "URI for `#{ adapter_name }' adapter is nil or empty. Please check env variables like `DATABASE_URL'."
        end
      end

      # It's raised when an operation is requested to an adapter after it was
      # disconnected.
      #
      # @since 0.5.0
      class DisconnectedAdapterError < Hanami::Model::Error
        def initialize
          super "You have tried to perform an operation on a disconnected adapter"
        end
      end

      # Represents a disconnected resource.
      #
      # When we use <tt>#disconnect</tt> for <tt>MemoryAdapter</tt> and
      # </tt>FileSystemAdapter</tt>, we want to free underlying resources such
      # as a mutex or a file descriptor.
      #
      # These adapters use to use anonymous descriptors that are destroyed by
      # Ruby VM after each operation. Sometimes we need to clean the state and
      # start fresh (eg. during a test suite or a deploy).
      #
      # Instead of assign <tt>nil</tt> to these instance variables, we assign this
      # special type: <tt>DisconnectedResource</tt>.
      #
      # In case an operation is still performed after the adapter was disconnected,
      # instead of see a generic <tt>NoMethodError</tt> for <tt>nil</tt>, a developer
      # will face a specific message relative to the state of the adapter.
      #
      # @api private
      # @since 0.5.0
      #
      # @see Hanami::Model::Adapters::Abstract#disconnect
      # @see Hanami::Model::Adapters::MemoryAdapter#disconnect
      # @see Hanami::Model::Adapters::FileSystemAdapter#disconnect
      class DisconnectedResource < Utils::BasicObject
        def method_missing(method_name, *)
          ::Kernel.raise DisconnectedAdapterError.new
        end
      end

      # Abstract adapter.
      #
      # An adapter is a concrete implementation that allows a repository to
      # communicate with a single database.
      #
      # Hanami::Model is shipped with Memory and SQL adapters.
      # Third part adapters MUST implement the interface defined here.
      # For convenience they may inherit from this class.
      #
      # These are low level details, and shouldn't be used directly.
      # Please use a repository for entities persistence.
      #
      # @since 0.1.0
      class Abstract
        # @since x.x.x
        # @api private
        #
        # @see Hanami::Model::Adapters::Abstract#adapter_name
        ADAPTER_NAME_SUFFIX = '_adapter'.freeze

        # Initialize the adapter
        #
        # @param mapper [Hanami::Model::Mapper] the object that defines the
        #   database to entities mapping
        #
        # @param uri [String] the optional connection string to the database
        #
        # @param options [Hash] a list of non-mandatory adapter options
        #
        # @since 0.1.0
        def initialize(mapper, uri = nil, options = {})
          @mapper = mapper
          @uri    = uri
          @options = options

          assert_uri_present!
        end

        # Creates or updates a record in the database for the given entity.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        # @param entity [Object] the entity to persist
        #
        # @return [Object] the entity
        #
        # @since 0.1.0
        def persist(collection, entity)
          raise NotImplementedError
        end

        # Creates a record in the database for the given entity.
        # It should assign an id (identity) to the entity in case of success.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        # @param entity [Object] the entity to create
        #
        # @return [Object] the entity
        #
        # @since 0.1.0
        def create(collection, entity)
          raise NotImplementedError
        end

        # Updates a record in the database corresponding to the given entity.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        # @param entity [Object] the entity to update
        #
        # @return [Object] the entity
        #
        # @since 0.1.0
        def update(collection, entity)
          raise NotImplementedError
        end

        # Deletes a record in the database corresponding to the given entity.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        # @param entity [Object] the entity to delete
        #
        # @since 0.1.0
        def delete(collection, entity)
          raise NotImplementedError
        end

        # Returns all the records for the given collection
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        #
        # @return [Array] all the records
        #
        # @since 0.1.0
        def all(collection)
          raise NotImplementedError
        end

        # Returns a unique record from the given collection, with the given
        # identity.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        # @param id [Object] the identity of the object.
        #
        # @return [Object] the entity
        #
        # @since 0.1.0
        def find(collection, id)
          raise NotImplementedError
        end

        # Returns the first record in the given collection.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        #
        # @return [Object] the first entity
        #
        # @since 0.1.0
        def first(collection)
          raise NotImplementedError
        end

        # Returns the last record in the given collection.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        #
        # @return [Object] the last entity
        #
        # @since 0.1.0
        def last(collection)
          raise NotImplementedError
        end

        # Empties the given collection.
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        #
        # @since 0.1.0
        def clear(collection)
          raise NotImplementedError
        end

        # Executes a command for the given query.
        #
        # @param query [Object] the query object to act on.
        #
        # @since 0.1.0
        def command(query)
          raise NotImplementedError
        end

        # Returns a query
        #
        # @param collection [Symbol] the target collection (it must be mapped).
        # @param blk [Proc] a block of code to be executed in the context of
        #   the query.
        #
        # @return [Object]
        #
        # @since 0.1.0
        def query(collection, &blk)
          raise NotImplementedError
        end

        # Wraps the given block in a transaction.
        #
        # For performance reasons the block isn't in the signature of the method,
        # but it's yielded at the lower level.
        #
        # Please note that it's only supported by some databases.
        # For this reason, the options may vary from adapter to adapter.
        #
        # @param options [Hash] options for transaction
        #
        # @see Hanami::Model::Adapters::SqlAdapter#transaction
        # @see Hanami::Model::Adapters::MemoryAdapter#transaction
        #
        # @since 0.2.3
        def transaction(options = {})
          raise NotImplementedError
        end

        # Returns a string which can be executed to start a console suitable
        # for the configured database.
        #
        # @return [String] to be executed to start a database console
        #
        # @since 0.3.0
        def connection_string
          raise NotSupportedError
        end

        # Executes a raw command
        #
        # @param raw [String] the raw statement to execute on the connection
        #
        # @return [NilClass]
        #
        # @since 0.3.1
        def execute(raw)
          raise NotImplementedError
        end

        # Fetches raw records from
        #
        # @param raw [String] the raw query
        # @param blk [Proc] an optional block that is yielded for each record
        #
        # @return [Enumerable<Hash>, Array<Hash>]
        #
        # @since 0.5.0
        def fetch(raw, &blk)
          raise NotImplementedError
        end

        # Disconnects the connection by freeing low level resources
        #
        # @since 0.5.0
        def disconnect
          raise NotImplementedError
        end

        # Adapter name
        #
        # @return [String] adapter name
        #
        # @since x.x.x
        def adapter_name
          Utils::String.new(self.class.name).demodulize.underscore.to_s.sub(ADAPTER_NAME_SUFFIX, '')
        end

        private

        def assert_uri_present!
          raise MissingURIError.new(adapter_name) if Utils::Blank.blank?(@uri)
        end
      end
    end
  end
end
