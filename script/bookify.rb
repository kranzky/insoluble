#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'json'

book = JSON.parse(File.read("book.json"), symbolize_names: true)

output = [
  "# #{book[:title]}",
  "### by #{book[:author]}"
]
book[:chapters].each.with_index do |chapter, chapter_index|
  output << ""
  output << "## Chapter #{chapter_index+1}: #{chapter[:name]}"
  section_count = chapter[:sections].count
  chapter[:sections].each.with_index do |section, section_index|
    if section_index > 1
      output << ""
      output << "---"
    end
    section[:generated].each do |paragraph|
      paragraph.split("\n").each do |line|
        output << ""
        output << line
      end
    end
  end
end
output << ""
output << "## THE END"

File.write("folly.md", output.join("\n"))
