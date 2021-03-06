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
  results = []
  ps.segment.each do |line|
    next if line.strip.empty?
    next if line !~ /[a-z]/
    type = line[0] == '"' ? 'dialogue' : 'exposition'
    if type == 'dialogue' && line.count('"') % 2 == 1
      return
    end
    puncs, norms, words = _decompose(line)
    results << [type, norms]
  end
  results.each do |result|
    yield result
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

def _learn(predictor, prev_sentence, sentence, max)
  prev_sentence.sort.uniq.each do |event|
    sentence.sort.uniq.each do |action|
      next if action == event
      next if action > max && event > max
      predictor.observe(event, action)
    end
  end
end

$count = 0
def _process(filename, predictor, observer, dictionary, exposition_norms, dialogue_norms, max)
  lines = File.readlines(filename)
  _each_chapter(lines) do |chapter|
    _each_paragraph(chapter) do |paragraph|
      prev_sentence = [1]
      _each_sentence(paragraph) do |sentence|
        type = sentence.shift
        sentence = sentence.first.map { |word| dictionary[word] ||= dictionary.length }.compact
        $count += 1 if sentence.length > 0
        sentence.each do |norm|
          if type == 'exposition'
            exposition_norms << norm
          elsif type == 'dialogue'
            dialogue_norms << norm
          end
        end
        _learn(predictor, sentence, sentence, max)
        unless sentence.first == 1
          observer.observe(1, 1)
          sentence.sort.uniq.each do |action|
            observer.observe(action, 1)
          end
        end
        prev_sentence = sentence
      end
      _learn(predictor, prev_sentence, prev_sentence, max)
      unless prev_sentence.first == 1
        observer.observe(1, 1)
        prev_sentence.sort.uniq.each do |action|
          observer.observe(action, 1)
        end
      end
    end
  end
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

def _infomagnetism(predictor, observer, event, action)
  total = observer.count(1).to_f
  p_action = observer.count(action) / total
  p_event = observer.count(event) / total
  p_action_given_event = predictor.frequency(event, action)
  p_action_and_event = p_action_given_event * p_event
  if p_action == 0 || p_event == 0 || p_action_given_event == 0 || p_action_and_event == 0
    return 0
  end
  (Math.log2(p_action_given_event) - Math.log2(p_action)) / -Math.log2(p_action_and_event)
end

def _keywords(sentences, predictor, observer, dictionary, decode, exposition_norms, dialogue_norms, max)
  return unless sentences.length == 3
  results = Hash.new { |h, k| h[k] = 0 }
  type = sentences[1].first
  limit =
    if type == 'exposition'
      exposition_norms
    elsif type == 'dialogue'
      dialogue_norms
    end
  limit.each do |id|
    sentences[1].last.each do |word|
      next if id == word
      force = _infomagnetism(predictor, observer, word, id)
      results[id] += force
    end
  end
  keywords = []
  candidates = results.to_a.shuffle
  candidates.sort! { |a, b| b[1] <=> a[1] }
  candidates[0..2].each do |v|
    keywords << v[0] if v[0] > 0
  end
  keywords << candidates.first[0] if keywords.empty?
  results = Hash.new { |h, k| h[k] = 0 }
  limit.each do |id|
    next if id > max
    keywords.each do |word|
      next if id == word
      force = _infomagnetism(predictor, observer, word, id)
      results[id] += force
    end
  end
  keywords = []
  candidates = results.to_a.shuffle
  candidates.sort! { |a, b| b[1] <=> a[1] }
  candidates[0..4].each do |v|
    keywords << v[0] if v[0] > 0
  end
  keywords << candidates.first[0] if keywords.empty?
  [[sentences[1].first,sentences[1].last.length], keywords.map { |w| decode[w] }]
end

dictionary = { "<error>" => 0, "<blank>" => 1 }

lines = File.readlines("template.txt")
lines.each do |line|
  line.strip!
  next if ['CHAPTER','PARAGRAPH', 'SECTION'].include?(line)
  type, line = line.split(':')
  puncs, norms, words = _decompose(line)
  next if norms.nil? || norms.empty?
  norms.each do |norm|
    dictionary[norm] ||= dictionary.length
  end
end

max = dictionary.values.max

predictor = Sooth::Predictor.new(0)
observer = Sooth::Predictor.new(0)
exposition_norms = Set.new
dialogue_norms = Set.new
files = Dir.glob('gutenberg/*.txt').shuffle
bar = ProgressBar.create(total: files.count)
files.each do |filename|
  _process(filename, predictor, observer, dictionary, exposition_norms, dialogue_norms, max)
  bar.increment
end

puts $count

decode = Hash[dictionary.to_a.map(&:reverse)]
lines = File.readlines("template.txt")
sentences = []
sentences << [:control, [1]]
lines.each do |line|
  line.strip!
  if ['CHAPTER','PARAGRAPH', 'SECTION'].include?(line) 
    sentences << [:control, [1]]
    sentences.shift while sentences.length > 3
    if sentences.length == 3
      keywords = _keywords(sentences, predictor, observer, dictionary, decode, exposition_norms, dialogue_norms, max)
      puts "#{keywords.first.join(';')}:#{keywords.last.join(' ')}"
      STDOUT.flush
    end
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
  if sentences.length == 3
    keywords = _keywords(sentences, predictor, observer, dictionary, decode, exposition_norms, dialogue_norms, max)
    puts "#{keywords.first.join(';')}:#{keywords.last.join(' ')}"
    sentences[1] = [sentences[1].first, keywords.last.map { |word| dictionary[word] }]
    STDOUT.flush
  end
end
sentences << [:control, [1]]
sentences.shift while sentences.length > 3
if sentences.length == 3
  keywords = _keywords(sentences, predictor, observer, dictionary, decode, exposition_norms, dialogue_norms, max)
  puts "#{keywords.first.join(';')}:#{keywords.last.join(' ')}"
  STDOUT.flush
end
