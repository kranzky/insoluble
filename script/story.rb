#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'json'

first_person = [true, true, true, false, true, false, true, false, true, false,
                true, false, true, false, false, false, false, false, false,
                false, false, false, false, false, true]

chapters = File.read("format.txt").split("\n")
title, author = chapters.shift(2)

book =
  {
    title: title,
    author: author,
    summary: "",
    chapters: chapters.map.with_index do |name, i|
      {
        name: name,
        mode: first_person[i] ? "first-person" : "third-person",
        sections: []
      }
    end
  }

paragraph = []
section =
  {
    templates: [],
    generated: []
  }
template = []
current_chapter = 0
File.read("keywords.txt").split("\n").each do |line|
  if ["PARAGRAPH", "SECTION", "CHAPTER"].include?(line)
    section[:templates] << template.clone if template.size > 0
    template = []
  else
    template << line
  end
  if ["SECTION", "CHAPTER"].include?(line)
    book[:chapters][current_chapter][:sections] << section.clone if section[:templates].size > 0
    current_chapter += 1 if "CHAPTER" == line && section[:templates].size > 0
    section[:templates] = []
  end
end

section[:templates] << template.clone if template.size > 0
book[:chapters][current_chapter][:sections] << section.clone if section[:templates].size > 0

File.write("book.json", JSON.pretty_generate(book))
