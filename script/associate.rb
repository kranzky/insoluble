#!/usr/bin/env ruby

require "awesome_print"
require 'byebug'
require 'pragmatic_segmenter'

def _each_sentence(lines)
  lines.map!(&:strip!)
  blob = lines.join(' ')
  ps = PragmaticSegmenter::Segmenter.new(text: blob)
  ps.segment.each do |line|
    # remove text within square brackets from line
    # ignore if all punctuation or empty
    # tag as dialogue or exposition
    yield line
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
    if line =~ /^CHAPTER\s/ || line =~ /^[IVX]+(\s\.-)/ || line.strip =~ /^[IXV]+$/ || line =~ /^_Chapter/ || line =~ /Chapter/
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

def _process(filename)
  lines = File.readlines(filename)
  count = 0
  _each_chapter(lines) do |chapter|
    _each_paragraph(chapter) do |paragraph|
      _each_sentence(paragraph) do |sentence|
        # puts sentence
      end
      puts "==="
    end
  end
end

Dir.glob('gutenberg/*.txt').shuffle.each do |filename|
  _process(filename)
end
