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

  describe '.maybe_create_subject' do
    let(:panoptes_yes) { double("PanoptesAdapter", subject_in_project?: { "id" => "1234", "metadata" => { "foo" => "bar" }, "external_id" => "ABC123" }) }
    let(:panoptes_no) { double("PanoptesAdapter", subject_in_project?: nil) }

    it 'does not create a subject when one already exists' do
      subject = create :subject
      expect(Subject.maybe_create_subject subject.id, nil).to be(nil)
      expect(panoptes_yes).not_to have_received(:subject_in_project?)
    end

    it 'creates a subject if allowed' do
      allow(Effects).to receive(:panoptes).and_return(panoptes_yes)
      wf = create :workflow

      expect(Subject.maybe_create_subject 1234, wf).not_to be(nil)
      expect(Subject.exists? 1234).to be(true)
      expect(Subject.find(1234).metadata['foo']).to eq('bar')
      expect(Subject.find(1234).external_id).to eq('ABC123')
    end

    it 'does not create a subject if not allowed' do
      allow(Effects).to receive(:panoptes).and_return(panoptes_no)
      wf = create :workflow

      expect(Subject.maybe_create_subject 1234, wf).to be(nil)
      expect(Subject.exists? 1234).to be(false)
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
