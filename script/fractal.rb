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

def _learn(predictor, sentence, keywords, universe)
  sentence << 1
  sentence.unshift(1)
  index = []
  sentence.each.with_index { |id, i| index << i if keywords.include?(id) }
  index.combination(2).each do |i, j|
    context = (sentence[i]..sentence[j])
    k = j-1
    while k != i
      event = universe[context] ||= universe.length
      action = sentence[k]
      predictor.observe(event, action)
      context = (sentence[i]..sentence[k])
      k -= 1
    end
    event = universe[context] ||= universe.length
    action = 1
    predictor.observe(event, action)
  end
end

def _generate(predictor, keywords)
  return keywords
end

$count = 0
def _process(filename, predictor, keywords, dictionary, universe)
  lines = File.readlines(filename)
  _each_chapter(lines) do |chapter|
    _each_paragraph(chapter) do |paragraph|
      _each_sentence(paragraph) do |sentence|
        type = sentence.shift
        sentence = sentence.first.map { |word| dictionary[word] ||= dictionary.length }.compact
        next unless sentence.any? { |id| keywords.include?(id) }
        $count += 1
        _learn(predictor, sentence, keywords, universe)
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

dictionary = { "<error>" => 0, "<blank>" => 1 }

# lines = File.readlines("keywords.txt")
# lines.each do |line|
#   line.strip!
#   next if ['CHAPTER','PARAGRAPH', 'SECTION'].include?(line) 
#   type, line = line.split(':')
#   puncs, norms, words = _decompose(line)
#   next if norms.nil? || norms.empty?
#   norms.each { |norm| dictionary[norm] ||= dictionary.length }
# end
dictionary["TELEPHONE"] ||= dictionary.length
dictionary["PURPLE"] ||= dictionary.length
dictionary["LOUNGE"] ||= dictionary.length
dictionary["BANANA"] ||= dictionary.length
dictionary["ANGRY"] ||= dictionary.length
dictionary["SCREAMED"] ||= dictionary.length
dictionary["WALKED"] ||= dictionary.length
dictionary["BENT"] ||= dictionary.length
dictionary["WAVE"] ||= dictionary.length
dictionary["LIPS"] ||= dictionary.length

keywords = Set.new
dictionary.values.each do |id|
  next if id < 1
  keywords << id
end

predictor = Sooth::Predictor.new(0)

files = Dir.glob('gutenberg/*.txt').shuffle
files = files[0..9]
bar = ProgressBar.create(total: files.count)
universe = {}
files.each do |filename|
  _process(filename, predictor, keywords, dictionary, universe)
  bar.increment
end

puts $count
decode = Hash[dictionary.to_a.map(&:reverse)]

10.times do
  sentence = _generate(predictor, keywords.to_a.shuffle[0..2])
  puts sentence.map { |id| decode[id] }.join(' ')
end
