#!/usr/bin/env ruby

require 'awesome_print'
require 'byebug'
require 'pragmatic_segmenter'
require 'sooth'
require 'ruby-progressbar'

def _each_sentence(lines)
  lines.map!(&:strip!)
  blob = lines.join(' ')
  blob.gsub!(/\s*\[([^\[\]]+)\]\s*/, ' ')
  blob.gsub!(/\s*\[([^\[\]]+)\]\s*/, ' ')
  ps = PragmaticSegmenter::Segmenter.new(text: blob)
  ps.segment.each do |line|
    next if line.strip.empty?
    next if line !~ /[a-z]/
    type = line[0] == '"' ? :dialogue : :exposition
    puncs, norms, words = _decompose(line)
    yield [type, norms]
  end
end

def _each_paragraph(lines)
  paragraph = []
  in_paragraph = false
  lines.each do |line|
    if line.strip.empty?
      yield paragraph if paragraph.length > 0
      paragraph = []
    else
      paragraph << line
    end
  end
end

def _each_chapter(lines)
  chapter = []
  preamble = []
  in_chapter = false
  in_preamble = false
  lines.each do |line|
    if line =~ /^CHAPTER\s/ || line =~ /^[IVX]+(\s\.-)/ || line.strip =~ /^[IXV]+$/ || line =~ /^_Chapter/ || line =~ /^Chapter/
      yield chapter if chapter.length > 49
      chapter = []
      preamble = []
      in_chapter = true
      in_preamble = true
    elsif line =~ /^PUBLICATIONS/ || line.strip =~ /^THE END/ || line.strip =~ /^(APPENDIX|Appendix|TAGGARD|Footnotes|PRINTED|FOOTNOTES|Henry James\'s Books)/
      yield chapter if chapter.length > 49
      chapter = []
      preamble = []
      in_chapter = false
      in_preamble = false
    elsif in_chapter
      if !line.strip.empty? && line !~ /^\s/ && line.strip =~ /[a-z]/ && line !~ /[\[]/
        in_preamble = false
      end
      chapter << line unless in_preamble
      preamble << line if in_preamble
      if line =~ /^\s+[^\s]/ && !in_preamble
        chapter = []
        preamble = []
        in_chapter = false
        in_preamble = false
      end
    end
  end
  yield chapter if chapter.length > 49
end

def _learn(predictor, prev_sentence, sentence)
  prev_sentence.sort.uniq.each do |event|
    sentence.sort.uniq.each do |action|
      predictor.observe(event, action)
    end
  end
end

def _process(filename, next_predictor, prev_predictor, dictionary)
  count = 0
  lines = File.readlines(filename)
  _each_chapter(lines) do |chapter|
    _each_paragraph(chapter) do |paragraph|
      prev_sentence = [1]
      _each_sentence(paragraph) do |sentence|
        count += 1
        type = sentence.shift
        sentence = sentence.first.map { |word| dictionary[word] ||= dictionary.length }
        _learn(next_predictor, prev_sentence, sentence)
        _learn(prev_predictor, sentence, prev_sentence)
        prev_sentence = sentence
      end
      _learn(next_predictor, prev_sentence, [1])
      _learn(prev_predictor, [1], prev_sentence)
    end
  end
  count
end

def _segment(line)
	sequence = line.split(/([[:word:]]+)/)
	sequence << "" if sequence.last =~ /[[:word:]]+/
	sequence.unshift("") if sequence.first =~ /[[:word:]]+/
	while index = sequence[1..-2].index { |item| item =~ /^['-]$/ } do
		sequence[index+1] = sequence[index, 3].join
		sequence[index] = nil
		sequence[index+2] = nil
		sequence.compact!
	end
	sequence.partition.with_index { |symbol, index| index.even? }
end

def _decompose(line, maximum_length=1024)
	return [nil, nil, nil] if line.nil?
	line = "" if line.length > maximum_length
	return [[], [], []] if line.length == 0
	puncs, words = _segment(line)
	norms = words.map(&:upcase)
	[puncs, norms, words]
end

dictionary = { "<error>" => 0, "<blank>" => 1 }
next_predictor = Sooth::Predictor.new(0)
prev_predictor = Sooth::Predictor.new(0)
files = Dir.glob('gutenberg/*.txt').shuffle
files = files[0..9]
bar = ProgressBar.create(total: files.count)
count = 0
files.each do |filename|
  count += _process(filename, next_predictor, prev_predictor, dictionary)
  bar.increment
end

# we have {count} sentences
# we have a model that counts event in first sentence and action in second sentence
# for a particular sentence, can find all actions, and the NPMI of each action
# either predictor can be used to find rare words in a sentence

decode = Hash[dictionary.to_a.map(&:reverse)]

lines = File.readlines("template.txt")
lines.each do |line|
  line.strip!
  if ['CHAPTER','PARAGRAPH'].include?(line) 
    puts line
    next
  end
  type, line = line.split(':')
  puncs, norms, words = _decompose(line)
  next if norms.nil? || norms.empty?
  sentence = norms.map { |word| dictionary[word] }.compact.sort.uniq
  sentence.map! { |id| decode[id] }
  puts "#{type}:#{sentence.join(' ')}"
end
