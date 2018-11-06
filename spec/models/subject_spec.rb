require 'spec_helper'

describe Subject, type: :model do
  describe '.update_cache' do
    it 'updates the cached metadata for a subject' do
      expect do
        described_class.update_cache("id" => 1, "metadata" => {"biome" => "ocean"})
      end.to change { Subject.count }.from(0).to(1)

      expect(Subject.first.metadata).to eq("biome" => "ocean")
    end
  end

  describe '#training_subject?' do
    it 'can tell if a subject is a training subject or not' do
      expect((create :subject, metadata: {'#training_subject' => 'true'}).training_subject?).to be(true)
      expect((create :subject, metadata: {'#training_subject' => 'false'}).training_subject?).to be(false)

      expect((create :subject, metadata: {'#training_subject' => 'TRUE'}).training_subject?).to be(true)
      expect((create :subject, metadata: {'#training_subject' => 'FALSE'}).training_subject?).to be(false)

      expect((create :subject, metadata: {'#training_subject' => 'blargh'}).training_subject?).to be(false)
      expect((create :subject, metadata: {'some_other_key' => 'FALSE'}).training_subject?).to be(false)
    end
  end
end
