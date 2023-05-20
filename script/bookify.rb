#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'json'

book = JSON.parse(File.read("horizon.json"), symbolize_names: true)

output = [
  "# #{book[:title]}",
]
output << ""
output << "## Prologue: #{book[:prologue][:name]}"
book[:prologue][:paragraphs].each do |line|
  output << ""
  output << line
end
book[:chapters].each.with_index do |chapter, chapter_index|
  output << ""
  output << "## Chapter #{chapter_index+1}: #{chapter[:name]}"
  chapter[:scenes] ||= []
  scene_count = chapter[:scenes].count
  chapter[:scenes].each.with_index do |scene, scene_index|
    if scene_index > 0
      output << ""
      output << "---"
    end
    scene[:text] ||= ""
    scene[:text].split("\n").each.with_index do |line, line_index|
      output << "" if line_index == 0
      output << line
    end
  end
end
output << ""
output << "## Epilogue: #{book[:epilogue][:name]}"
book[:epilogue][:paragraphs] ||= []
book[:epilogue][:paragraphs].each do |line|
  output << ""
  output << line
end
output << ""
output << "# THE END"

File.write("horizon.md", output.join("\n"))
