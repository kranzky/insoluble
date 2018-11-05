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
  blob.gsub!(/[_]/, '')
  blob.gsub!(/\.\.\.+/, '…')
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

def _learn(predictor, prev_sentence, sentence, skip=false)
  prev_sentence.sort.uniq.each do |event|
    sentence.sort.uniq.each do |action|
      next if skip && action == event
      predictor.observe(event, action)
    end
  end
end

def _process(filename, next_predictor, prev_predictor, scan_predictor, dictionary)
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
        _learn(scan_predictor, sentence, sentence, true)
        prev_sentence = sentence
      end
      _learn(next_predictor, prev_sentence, [1])
      _learn(prev_predictor, [1], prev_sentence)
      _learn(scan_predictor, prev_sentence, prev_sentence, true)
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

def _infomagnetism(pair_predictor, predictor, event, action, total)
  p_action = predictor.count(action) / total.to_f
  p_event = predictor.count(event) / total.to_f
  p_action_given_event = pair_predictor.frequency(event, action)
  if p_action == 0 || p_event == 0 || p_action_given_event == 0
    return 0
  end
  p_action_given_event * p_event * (Math.log2(p_action_given_event) - Math.log2(p_action))
end

def _keywords(sentences, next_predictor, prev_predictor, scan_predictor, dictionary, decode, total)
  return unless sentences.length == 3
  results = Hash.new { |h, k| h[k] = 0 }
  dictionary.values.each do |id|
    next if id < 2
    sentences[0].last.each do |word|
      force = _infomagnetism(next_predictor, scan_predictor, word, id, total)
      results[id] += force if force > results[id]
    end
    sentences[1].last.each do |word|
      next if id == word
      force = _infomagnetism(scan_predictor, scan_predictor, word, id, total)
      results[id] += force if force > results[id]
    end
    sentences[2].last.each do |word|
      force = _infomagnetism(prev_predictor, scan_predictor, word, id, total)
      results[id] += force if force > results[id]
    end
  end
  keywords = []
  candidates = results.to_a.sort { |a, b| b[1] <=> a[1] }[0..2]
  candidates.each do |v|
    keywords << v[0] if v[1] > 0
  end
  [[sentences[1].first,sentences[1].last.length], keywords.shuffle.map { |w| decode[w] }]
end

dictionary = { "<error>" => 0, "<blank>" => 1 }
next_predictor = Sooth::Predictor.new(0)
prev_predictor = Sooth::Predictor.new(0)
scan_predictor = Sooth::Predictor.new(0)
files = Dir.glob('gutenberg/*.txt').shuffle
files = files[0..499]
bar = ProgressBar.create(total: files.count)
count = 0
files.each do |filename|
  count += _process(filename, next_predictor, prev_predictor, scan_predictor, dictionary)
  bar.increment
end

decode = Hash[dictionary.to_a.map(&:reverse)]

lines = File.readlines("template.txt")
sentences = []
sentences << [:control, [1]]
lines.each do |line|
  line.strip!
  if ['CHAPTER','PARAGRAPH'].include?(line) 
    sentences << [:control, [1]]
    sentences.shift while sentences.length > 3
    keywords = _keywords(sentences, next_predictor, prev_predictor, scan_predictor, dictionary, decode, count)
    puts "#{keywords.first.join(';')}:#{keywords.last.join(' ')}" unless keywords.nil?
    sentences = []
    sentences << [:control, [1]]
    puts line
    next
  end
  type, line = line.split(':')
  puncs, norms, words = _decompose(line)
  next if norms.nil? || norms.empty?
  sentence = norms.map { |word| dictionary[word] }.compact.sort.uniq
  sentences << [type, sentence]
  sentences.shift while sentences.length > 3
  keywords = _keywords(sentences, next_predictor, prev_predictor, scan_predictor, dictionary, decode, count)
  puts "#{keywords.first.join(';')}:#{keywords.last.join(' ')}" unless keywords.nil?
end
sentences << [:control, [1]]
sentences.shift while sentences.length > 3
keywords = _keywords(sentences, next_predictor, prev_predictor, scan_predictor, dictionary, decode, count)
puts "#{keywords.first.join(';')}:#{keywords.last.join(' ')}" unless keywords.nil?
