module Reducers
  class SummaryStatisticsReducer < Reducer
    config_field :summarize_field
    config_field :operations

    attr_reader :extracts

    @@valid_operations = [
      "count",
      "min",
      "max",
      "sum",
      "product",
      "mean",
      "sse",
      "variance",
      "stdev",
      "first",
      "median",
      "mode"
    ]

    validate do
      unless config["summarize_field"].present?
        errors.add("summarize_field", "No field specified for operations")
      else
        if config["summarize_field"].ends_with? "."
          errors.add("summarize_field", "Invalid summarize_field specified")
        end
      end

      unless config["operations"].present?
        errors.add("operations", "No operation(s) specified")
      else
        operations = config["operations"]
        unless operations.is_a? Array or operations.is_a? String
          errors.add("operations", "Invalid operations specification")
        else
          if(operations.is_a? String)
            unless @@valid_operations.include? operations
              errors.add("operations", "Invalid operation '#{operations}'")
            end
          end
          if(operations.is_a? Array)
            if(operations.empty?)
              errors.add("operations", "No operation(s) specified")
            end
            operations.each do |operation|
              unless operation.is_a? String and @@valid_operations.include? operation
                errors.add("operations", "Invalid operation #{operation}")
              end
            end
          end
        end
      end
    end

    def reduction_data_for(extracts)
      @extracts = extracts
      {}.tap do |result|
        operations.each do |operation|
          if @@valid_operations.include? operation
            result[operation] = self.send(operation)
          end
        end
      end
    end

    private

    def count
      @count ||= values.count
      @count
    end

    def min
      @min ||= values.min
      @min
    end

    def max
      @max ||= values.max
      @max
    end

    def first
      @first ||= values.first
      @first
    end

    def sum
      @sum ||= values.reduce(:+)
      @sum
    end

    def product
      @product ||= values.reduce(:*)
      @product
    end

    def mean
      @mean ||= sum / count
      @mean
    end

    def sse
      @sse ||= values.map do |value|
        (value-mean)**2
      end.reduce(:+)

      @sse
    end

    def variance
      @variance ||= sse / (count-1)

      @variance
    end

    def stdev
      @stdev ||= Math.sqrt(variance)
      @stdev
    end

    def median
      @median ||= (sorted_values[(count - 1) / 2] + sorted_values[count / 2]) / 2.0
      @median
    end

    def mode
      @mode ||= values.group_by{|i| i}.sort_by{|key, group| group.count}.last.first
      @mode
    end

    def sorted_values
      @sorted_values ||= values.sort
      @sorted_values
    end

    def values
      @values ||= relevant_extracts.map do |extract|
        if extract.data[field_name].present?
          extract.data[field_name].to_f
        else
          nil
        end
      end.select{ |value| not value.nil? }
      @values
    end

    def relevant_extracts
      return extracts if extractor_name.blank?
      return extracts.select { |extract| extract.extractor_key == extractor_name }
    end

    def summarize_field
      config['summarize_field']
    end

    def operations
      if config['operations'].is_a? Array
        config['operations'].uniq
      else
        [config['operations']]
      end
    end

    def extractor_name
      return nil unless summarize_field.include? "."
      summarize_field.split(".")[0]
    end

    def field_name
      return summarize_field if extractor_name.blank?
      summarize_field.split(".")[1]
    end
  end
end