class ExtractFilter
  include ActiveModel::Validations

  REPEATED_CLASSIFICATIONS = ["keep_first", "keep_last", "keep_all"].freeze
  EMPTY_EXTRACTS = ["keep_all", "ignore_empty"].freeze
  TRAINING_BEHAVIOR = ["ignore_training", "training_only", "experiment_only"].freeze
  FILTER_SEQUENCE = [
      :filter_by_repeatedness,
      :filter_by_extractor_keys,
      :filter_by_emptiness,
      :filter_by_training_behavior,
      :filter_by_subrange
  ].freeze

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
    extract_groups = ExtractsForClassification.from(extracts)
    apply_filters(extract_groups)
  end

  private

  def apply_filters(extract_groups)
    filtered = extract_groups
    FILTER_SEQUENCE.each do |filter_symbol|
      filtered = send(filter_symbol, filtered)
    end
    filtered.flat_map(&:extracts)
  end

  def filter_by_repeatedness(extract_groups)
    case repeated_classifications
    when "keep_all"
      extract_groups
    when "keep_first"
      keep_first_classification(extract_groups)
    when "keep_last"
      keep_first_classification(extract_groups.reverse).reverse
    end
  end

  def filter_by_subrange(extract_groups)
    extract_groups.select do |extract_group|
      extract_group.extracts.length > 0
    end.sort_by(&:classification_at)[subrange]
  end

  def filter_by_training_behavior(extract_groups)
    case training_behavior
    when "ignore_training"
      extract_groups
    when "training_only"
      extract_groups.each do |extract_group|
        extract_group.extracts.select! do |extract|
          extract.subject.training_subject?
        end
      end.select do |extract_group|
        extract_group.extracts.length > 0
      end # remove extracts for non-training subjects
    when "experiment_only"
      extract_groups.each do |extract_group|
        extract_group.extracts.reject! do |extract|
          extract.subject.training_subject?
        end
      end.select do |extract_group|
        extract_group.extracts.length > 0
      end # remove extracts for training subjects
    end
  end

  def filter_by_extractor_keys(extract_groups)
    return extract_groups if extractor_keys.blank?

    extract_groups.map do |group|
      group.select do |extract|
        extractor_keys.include?(extract.extractor_key)
      end
    end
  end

  def filter_by_emptiness(extract_groups)
    case empty_extracts
    when "keep_all"
      extract_groups
    when "ignore_empty"
      extract_groups.map do |extract_group|
        extract_group.select { |extract| extract.data.present? }
      end
    end
  end

  def keep_first_classification(extract_groups)
    subjects ||= Hash.new

    extract_groups.select do |extracts_for_classification|
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
