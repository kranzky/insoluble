#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'

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
    section[:templates] << template.join("\n") if template.size > 0
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

debugger

exit

OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
end

client = OpenAI::Client.new

response =
  client.chat(
    parameters: {
      model: "gpt-4",
      messages: [{ role: "user", content: "Hello!"}],
      temperature: 0.7
    }
  )

ap response
