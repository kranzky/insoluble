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
    next if line =~ /[0-9]/
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

def _learn(predictor, sentence, keywords, universe, blacklist)
  return false if sentence.any? { |id| blacklist.include?(id) }
  sentence << 1
  sentence.unshift(1)
  index = []
  sentence.each.with_index { |id, i| index << i if keywords.include?(id) }
  index.combination(2).each do |i, j|
    context = (sentence[i]..sentence[j])
    k = j-1
    while k != i
      action = sentence[k]
      event = universe[context] ||= universe.length
      predictor.observe(event, action)
      context = (sentence[i]..sentence[k])
      k -= 1
    end
    event = universe[context] ||= universe.length
    action = 1
    predictor.observe(event, action)
  end
  true
end

def _generate_segment(predictor, context, universe)
  segment = []
  first = context.first
  final = context.last
  while true
    event = universe[context]
    if event.nil? || predictor.count(event) == 0
      event = universe[(1..context.last)]
    end
    return if event.nil?
    count = predictor.count(event)
    return if count == 0
    limit = rand(1..count)
    action = predictor.select(event, limit)
    return if action.nil?
    break if action == 1
    segment << action
    context = (first..action)
  end
  segment.reverse!
  segment << final unless final == 1
  return segment
end

def _generate(predictor, keywords, universe)
  segments = []
  sentence = []
  keywords << 1
  context = (1..keywords.shift)
  while true
    segment = _generate_segment(predictor, context, universe)
    return if segment.nil?
    segments << segment
    break if keywords.empty?
    context = (context.last..keywords.shift)
  end
  return segments.flatten
end

def _generate_all(predictor, keywords, universe)
  length = [keywords.length, 4].max
  sentences = []
  while length > 0
    keywords.permutation(length).each do |index|
      100.times do
        sentence = _generate(predictor, index.clone, universe)
        sentences << sentence unless sentence.nil?
      end
    end
    length -= 1
  end
  if sentences.empty?
    100.times do
      sentence = _generate(predictor, [], universe)
      sentences << sentence unless sentence.nil?
    end
  end
  return sentences
end

$count = 0
def _process(filename, exposition_predictor, dialogue_predictor, keywords, dictionary, universe, blacklist)
  lines = File.readlines(filename)
  _each_chapter(lines) do |chapter|
    _each_paragraph(chapter) do |paragraph|
      _each_sentence(paragraph) do |sentence|
        type = sentence.shift
        sentence = sentence.first.map { |word| dictionary[word] ||= dictionary.length }.compact
        next unless sentence.any? { |id| keywords.include?(id) }
        if type == "exposition"
          $count += 1 if _learn(exposition_predictor, sentence, keywords, universe, blacklist)
        elsif type == "dialogue"
          $count +=1 if _learn(dialogue_predictor, sentence, keywords, universe, blacklist)
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

def _choose_best(sentences, keywords, length)
  sentence = nil
  best_score = -1
  best_diff = 1000
  sentences.each do |candidate|
    score = (candidate & keywords).count
    diff = candidate.length - length
    if diff >= 0 && (diff - score * 2) < (best_diff - best_score * 2)
      best_score = score
      best_diff = diff
      sentence = candidate
    end
  end
  [[best_score, best_diff], sentence]
end

title = nil
author = nil
chapters = []
format = File.readlines("format.txt")
format.each do |line|
  line.strip!
  if title.nil?
    title = line
  elsif author.nil?
    author = line
  else
    chapters << line
  end
end

novel = []
novel << "# #{title}"
novel << "### by #{author}"
novel << ""

dictionary = { "<error>" => 0, "<blank>" => 1 }

paragraph = []
lines = File.readlines("generated.txt")
lines.each do |line|
  line.strip!
  if line == "CHAPTER"
    unless paragraph.empty?
      novel << paragraph.join(" ")
      paragraph = []
      novel << ""
    end
    novel << "## #{chapters.shift}"
    novel << ""
  elsif line == "SECTION"
    novel << paragraph.join(" ")
    paragraph = []
    novel << ""
    novel << "---"
    novel << ""
  elsif line == "PARAGRAPH"
    novel << paragraph.join(" ")
    paragraph = []
    novel << ""
  else
    tmp, line = line.split(':')
    type, length = tmp.split(';')
    if type == 'exposition'
      paragraph << "#{line.capitalize}."
    elsif type == 'dialogue'
      paragraph << "\"#{line.capitalize}.\""
    end
  end
end
novel << paragraph.join(" ")

novel.each do |line|
  puts line
end
