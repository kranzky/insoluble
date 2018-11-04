#!/usr/bin/env ruby

require "awesome_print"
require 'byebug'

# iterate through all gutenberg texts

# for a particular text, search for a chapter marker
  # - begins with uppercase CHAPTER or uppercase roman numeral
  # - followed by at least 10 lines (so not in TOC)

def _each_chapter(lines)
  chapter = []
  inside = false
  lines.each do |line|
    if line =~ /^CHAPTER\s/
      yield chapter if chapter.length > 9
      chapter = []
      inside = true
    elsif inside
      chapter << line
    end
  end
  yield chapter if chapter.length > 9
end

def _process(filename)
  lines = File.readlines(filename)
  count = 0
  _each_chapter(lines) do |chapter|
    puts "===#{filename}===" if count == 0
    count += 1
    puts "---#{count}---"
    puts chapter.join
  end
end

Dir.glob('gutenberg/*.txt').each do |filename|
  _process(filename)
end
