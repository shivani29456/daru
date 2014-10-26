require_relative 'dataframe_by_row.rb'
require_relative 'dataframe_by_vector.rb'


module Daru
  class DataFrame

    attr_reader :vectors
    attr_reader :index
    attr_reader :name
    attr_reader :size

    # DataFrame basically consists of an Array of Vector objects.
    # These objects are indexed by row and column by vectors and index Index objects.
    def initialize source, *args
      vectors = args.shift
      index   = args.shift
      @name   = args.shift || SecureRandom.uuid

      @data = []

      if source.empty?
        @vectors = Daru::Index.new vectors
        @index   = Daru::Index.new index

        create_empty_vectors
      else
        case source
        when Array
          @vectors = Daru::Index.new (vectors + (source[0].keys - vectors)).uniq.map(&:to_sym)
          if index.nil?
            @index = Daru::Index.new source.size
          else
            @index = Daru::Index.new index
          end

          @vectors.each do |name|
            v = []

            source.each do |hsh|
              v << hsh[name]
            end

            @data << v.dv(name, @index)
          end
        when Hash
          vectors = source.keys.sort      if vectors.nil?
          index   = source.values[0].size if index.nil?

          if vectors.is_a?(Daru::Index) or index.is_a?(Daru::Index)
            @vectors = vectors.to_index
            @index   = index.to_index
          else
            @vectors = Daru::Index.new (vectors + (source.keys - vectors)).uniq.map(&:to_sym)
            @index   = Daru::Index.new index     
          end

          @vectors.each do |name|
            @data << source[name].dv(name, @index).dup
          end
        end
      end

      @size = @index.size

      validate
    end

    def [](*names, axis)
      if axis == :vector
        access_vector names
      elsif axis == :row
        access_row names
      else
        raise IndexError, "Expected axis to be row or vector not #{axis}"
      end
    end

    def []=(name, axis ,vector)
      if axis == :vector
        @vectors = @vectors.re_index(@vectors + name)

        insert_vector name, vector
      elsif axis == :row        
        insert_or_modify_row name, vector
      else
        raise IndexError, "Expected axis to be row or vector, not #{axis}."
      end
    end

    def vector
      Daru::DataFrameByVector.new(self)
    end

    def row
      Daru::DataFrameByRow.new(self)
    end

    def each_vector
      
    end

    def each_vector_with_index
      
    end

    def each_row
      
    end

    def each_row_with_index
      
    end

    def has_vector? name
      !!@vectors[name]
    end

    def insert_vector name, vector
      if @vectors.include? name
        validate_vector_indexes vector if vector.is_a?(Daru::Vector)

        v = vector.dv(name, @index)

        @data[@vectors[name]] = vector.dv(name, @index)
      else
        raise Exception, "Vector named #{name} not found in Index."
      end
    end

    def == other
      @index == other.index and @size == other.size and 
      @vectors.each do |vector|
        self[vector, :vector] == other[vector, :vector]
      end
    end

    def method_missing(name, *args)
      if md = name.match(/(.+)\=/)
        insert_vector name[/(.+)\=/].delete("="), args[0]
      elsif self.has_vector? name
        self[name, :vector]
      else
        super(name, *args)
      end
    end

   private

    def access_vector names
      unless names[1]
        if @vectors.index_class != Integer and names[0].is_a?(Integer)
          return @data[names[0]]
        else
          return @data[@vectors[names[0]]]
        end
      end

      new_vcs = {}

      names.each do |name|
        name = name.to_sym unless name.is_a?(Integer)

        new_vcs[name] = @data[@vectors[name]]
      end

      Daru::DataFrame.new new_vcs, new_vcs.keys, @index, @name
    end

    def access_row names
      unless names[1]
        row = []

        @vectors.each do |vector|
          row << @data[@vectors[vector]][names[0]]
        end

        if @vectors.index_class != Integer and names[0].is_a?(Integer)
          name = @index.key names[0]
        else
          name = names[0]
        end

        Daru::Vector.new name, row, @vectors
      else
      end
    end

    def insert_or_modify_row name, vector      
      if @index.include? name
        validate_vector_indexes vector, @vectors if vector.is_a?(Daru::Vector)

        v = vector.dv(name, @vectors)

        @vectors.each do |vector|
          @data[@vectors[vector]][name] = v[vector]
        end
      else
        @index = @index.re_index(@index + name)

        validate_vector_indexes vector, @vectors if vector.is_a?(Daru::Vector)

        v = vector.dv(name, @vectors)

        @vectors.each do |vector|
          @data[@vectors[vector]].concat v[vector], name
        end
      end
    end

    def create_empty_vectors
      @vectors.each do |name|
        @data << Daru::Vector.new(name, [], @index)
      end
    end

    def validate_labels
      raise IndexError, "Expected equal number of vectors for number of Hash pairs" if 
        @vectors.size != @data.size

      raise IndexError, "Expected number of indexes same as number of rows" if
        @index.size != @data[0].size
    end

    def validate_vector_sizes
      @data.each do |vector|
        raise IndexError, "Expected vectors with equal length" if vector.size != @size
      end
    end

    def validate_vector_indexes single_vector=nil, index=nil
      index = @index if index.nil?

      if single_vector.nil?
        @data.each do |vector|
          raise NotImplementedError, "Expected matching indexes in all vectors. DataFrame with mismatched indexes not implemented yet." unless 
            vector.index == index 
        end
      else
        raise IndexError, "Expected same index as DataFrame" unless 
          single_vector.index == index
      end
    end

    def validate
      # TODO: [IMP] when vectors of different dimensions are specified, they should
      # be inserted into the dataframe by inserting nils wherever necessary.
      validate_labels
      validate_vector_indexes 
      validate_vector_sizes
    end
  end
end