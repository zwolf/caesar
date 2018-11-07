require 'facets/method/composition'

class ExtractFilter
  include ActiveModel::Validations

  REPEATED_CLASSIFICATIONS = ["keep_first", "keep_last", "keep_all"]
  EMPTY_EXTRACTS = ["keep_all", "ignore_empty"]
  TRAINING_BEHAVIOR = ["ignore_training", "training_only", "experiment_only"]

  validates :repeated_classifications, inclusion: {in: REPEATED_CLASSIFICATIONS}
  validates :empty_extracts, inclusion: {in: EMPTY_EXTRACTS}
  validates :training_behavior, inclusion: {in: TRAINING_BEHAVIOR}
  validates :from, numericality: true
  validates :to, numericality: true

  attr_reader :filters

  def initialize(filters)
    @filters = filters.with_indifferent_access
  end

  def filter(extracts)
    extracts = ExtractsForClassification.from(extracts)

    filter_sequence = [
      :filter_by_repeatedness,
      :filter_by_extractor_keys,
      :filter_by_emptiness,
      :filter_by_subrange
    ]

    composed = compose_filters(filter_sequence)
    apply_filters(extracts, composed)
  end

  private

  def compose_filters(filter_list)
    filter_list.map{ |s| self.method(s) }.inject{ |rhs, op| rhs ? op * rhs : op }
  end

  def apply_filters(extracts, filters)
    filters.call(extracts)[0].flat_map(&:extracts)
  end

  def filter_by_repeatedness(extracts)
    case repeated_classifications
    when "keep_all"
      [extracts]
    when "keep_first"
      [keep_first_classification(extracts)]
    when "keep_last"
      [keep_first_classification(extracts.reverse).reverse]
    end
  end

  def filter_by_subrange(extracts)
    [extracts.select do |extract_group|
      extract_group.extracts.length > 0
    end.sort_by(&:classification_at)[subrange]]
  end

  def filter_by_extractor_keys(extracts)
    return [extracts] if extractor_keys.blank?

    [extracts.map do |group|
      group.select do |extract|
        extractor_keys.include?(extract.extractor_key)
      end
    end]
  end

  def filter_by_emptiness(extracts)
    case empty_extracts
    when "keep_all"
      [extracts]
    when "ignore_empty"
      [extracts.map do |extract_group|
        extract_group.select { |extract| extract.data.present? }
      end]
    end
  end

  def keep_first_classification(extracts)
    subjects ||= Hash.new

    extracts.select do |extracts_for_classification|
      subject_id = extracts_for_classification.subject_id
      user_id = extracts_for_classification.user_id

      subjects[subject_id] = Set.new unless subjects.has_key? subject_id
      id_list = subjects[subject_id]

      next true unless extracts_for_classification.user_id
      next false if id_list.include?(user_id)
      id_list << user_id
      true
    end.to_a
  end

  def from
    (filters["from"] || 0).to_i
  end

  def to
    (filters["to"] || -1).to_i
  end

  def subrange
    Range.new(from, to)
  end

  def extractor_keys
    Array.wrap(filters["extractor_keys"] || [])
  end

  def repeated_classifications
    filters["repeated_classifications"] || "keep_first"
  end

  def empty_extracts
    filters["empty_extracts"] || "keep_all"
  end

  def training_behavior
    filters["training_behavior"] || "ignore_training"
  end
end
