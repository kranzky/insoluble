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
    results << [type, [puncs, norms, words]]
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

def _learn(case_predictor, punc_predictor, puncs, norms, words, universe, max)
  return if norms.empty?
  prev_norm = 1
  norms.each.with_index do |norm, i|
    if norm < max
      context = [prev_norm, norm]
      event = universe[context] ||= universe.length
      action = puncs[i]
      punc_predictor.observe(event, action)
      context = [prev_norm, action, norm]
      event = universe[context] ||= universe.length
      action = words[i]
      case_predictor.observe(event, action)
    end
    prev_norm = norm
  end
  if norms.last <= max
    context = [norms.last, 1]
    event = universe[context] ||= universe.length
    action = puncs.last
    punc_predictor.observe(event, action)
  end
  true
end

$count = 0
def _process(filename, exposition_case_predictor, exposition_punc_predictor, dialogue_case_predictor, dialogue_punc_predictor, dictionary, universe, max)
  lines = File.readlines(filename)
  _each_chapter(lines) do |chapter|
    _each_paragraph(chapter) do |paragraph|
      _each_sentence(paragraph) do |sentence|
        type = sentence.shift
        puncs, norms, words = sentence.first
        puncs.map! { |word| dictionary[word] ||= dictionary.length }.compact
        norms.map! { |word| dictionary[word] ||= dictionary.length }.compact
        words.map! { |word| dictionary[word] ||= dictionary.length }.compact
        if type == "exposition"
          $count += 1 if _learn(exposition_case_predictor, exposition_punc_predictor, puncs, norms, words, universe, max)
        elsif type == "dialogue"
          $count +=1 if _learn(dialogue_case_predictor, dialogue_punc_predictor, puncs, norms, words, universe, max)
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


def _try_repair(norms, case_predictor, punc_predictor, universe)
  puncs = []
  words = []
  prev_norm = 1
  norms.each do |norm|
    context = [prev_norm, norm]
    event = universe[context]
    action =
      if event.nil?
        1
      else
        count = punc_predictor.count(event)
        if count == 0
          0
        else
          limit = rand(1..count)
          punc_predictor.select(event, limit)
        end
      end
    puncs << action
    context = [prev_norm, action, norm]
    event = universe[context]
    action =
      if event.nil?
        1
      else
        count = case_predictor.count(event)
        if count == 0
          0
        else
          limit = rand(1..count)
          case_predictor.select(event, limit)
        end
      end
    words << action
    prev_norm = norm
  end
  context = [norms.last, 1]
  event = universe[context]
  action =
    if event.nil?
      1
    else
      count = punc_predictor.count(event)
      if count == 0
        0
      else
        limit = rand(1..count)
        punc_predictor.select(event, limit)
      end
    end
  puncs << action
  [puncs, words]
end

def _evaluate(puncs)
  line = puncs.join
  return false if line.count('"') % 2 == 1
  return false if line.count("'") % 2 == 1
  return false if line.count("(") != line.count(")")
  true
end

def _repair(norms, case_predictor, punc_predictor, universe, decode)
  attempt = 0
  while true
    attempt += 1
    puncs, words = _try_repair(norms, case_predictor, punc_predictor, universe)
    next unless _evaluate(puncs.map { |punc| decode[punc] }) || attempt >= 100
    return puncs.zip(words).flatten.compact.map { |id| decode[id] }.join
  end
end

dictionary = { "<error>" => 0, "<blank>" => 1 }
lines = File.readlines("generated.txt")
lines.each do |line|
  line.strip!
  next if ['CHAPTER','PARAGRAPH', 'SECTION'].include?(line)
  type, line = line.split(':')
  norms = line.split(' ')
  norms.each do |norm|
    dictionary[norm] ||= dictionary.length
  end
end
max = dictionary.length

universe = {}
exposition_case_predictor = Sooth::Predictor.new(0)
exposition_punc_predictor = Sooth::Predictor.new(0)
dialogue_case_predictor = Sooth::Predictor.new(0)
dialogue_punc_predictor = Sooth::Predictor.new(0)
files = Dir.glob('gutenberg/*.txt').shuffle
bar = ProgressBar.create(total: files.count)
files.each do |filename|
  _process(filename, exposition_case_predictor, exposition_punc_predictor, dialogue_case_predictor, dialogue_punc_predictor, dictionary, universe, max)
  bar.increment
end

puts $count
decode = Hash[dictionary.to_a.map(&:reverse)]

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

count = 0
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
    count += 1
    novel << "## Chapter #{count}: #{chapters.shift}"
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
    norms = line.split(' ').map { |word| dictionary[word] || 0 }
    if type == 'exposition'
      paragraph << _repair(norms, exposition_case_predictor, exposition_punc_predictor, universe, decode)
    elsif type == 'dialogue'
      paragraph << _repair(norms, dialogue_case_predictor, dialogue_punc_predictor, universe, decode)
    end
  end
end
novel << paragraph.join(" ")

novel.each do |line|
  puts line
end
