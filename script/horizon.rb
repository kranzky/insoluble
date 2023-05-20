#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

#===============================================================================

def get_response(prompt)
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
  end
  client = OpenAI::Client.new
  request =
    {
      model: "gpt-4",
      temperature: 0.7,
      messages: prompt.split("\n").map do |message|
        {
          role: "user",
          content: message
        }
      end
    }
  response = client.chat(parameters: request)
  result = response.dig("choices", 0, "message", "content")
  raise "no response" if result.nil?
  result
end

#-------------------------------------------------------------------------------

def generate_prologue_summary
  return if $book[:prologue][:summary]
  puts "Generating prologue summary..."
  prompt = <<~PROMPT
    We are writing a novel together. Here is the prologue that you wrote for it:
    
    #{$book[:prologue][:paragraphs].join("\n\n")}

    Write a single paragraph which summarises this prologue.
  PROMPT
  $book[:prologue][:summary] = get_response(prompt)
  $book[:state][:changed] = true
ensure
  $book[:state][:name] = "chapters"
  $book[:state][:chapter][:name] = "context"
  $book[:state][:chapter][:index] = 0
end

#-------------------------------------------------------------------------------

def generate_chapter_context
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  return if chapter[:context]
  puts "Generating chapter context..."
  prompt = <<~PROMPT
    We are writing a novel together. Here is a summary of what you have written so far:
      
    # TODO: chapter summaries
    
    Write a single paragraph which summarises the story so far.
  PROMPT
  chapter[:context] = get_response(prompt)
  $book[:state][:changed] = true
ensure
  $book[:state][:chapter][:name] = "scenes"
end

#-------------------------------------------------------------------------------

def generate_chapters
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  case $book[:state][:chapter][:name]
  when "context"
    generate_chapter_context
  when "scenes"
    generate_scenes
  when "scene"
    generate_scene
  when "summary"
    raise "not implemented"
  end
end

#-------------------------------------------------------------------------------

def characters
  $book[:characters].map do |character|
    "#{character[:name]}: #{character[:description]}"
  end.join("\n")
end

#-------------------------------------------------------------------------------

def locations
  $book[:locations].map do |locations|
    "#{locations[:name]}: #{locations[:description]}"
  end.join("\n")
end

#-------------------------------------------------------------------------------

def generate_scenes
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  return if chapter[:scenes]
  puts "Generating chapter scenes..."
  prompt = <<~PROMPT
    We are writing a novel together. Here is a list of characters:

    #{characters}

    Here is a list of locations:

    #{locations}

    Here is a summary of the story so far:

    #{chapter[:context]}

    We are about to write a new chapter. Here's what needs to happen in this chapter:
    
    #{chapter[:prompt]}
    
    Bearing in mind the rules of narrative, and making sure to be consistent with the story so far, write a list of scenes which will make up this chapter.
    This should be presented as a list of prompts, one for each scene, which will be used to generate the scene.
    Give your answer in the form of a JSON array of objects, with each object containing name and prompt keys.
  PROMPT
  chapter[:scenes] = JSON.parse(get_response(prompt))
  $book[:state][:changed] = true
ensure
  $book[:state][:chapter][:name] = "scene"
  $book[:state][:scene][:name] = "context"
  $book[:state][:scene][:index] = 0
end

#-------------------------------------------------------------------------------

def generate_scene
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  scene = chapter[:scenes][$book[:state][:scene][:index]]
  case $book[:state][:scene][:name]
  when "context"
    raise "not implemented"
  when "scenes"
    raise "not implemented"
  when "scene"
    raise "not implemented"
  when "summary"
    raise "not implemented"
  end
end

#===============================================================================

$book = JSON.parse(File.read("horizon.json"), symbolize_names: true)
$book[:state][:changed] = false

while !$book[:state][:changed]
  case $book[:state][:name]
  when "prologue"
    generate_prologue_summary
  when "chapters"
    generate_chapters
  when "epilogue"
    raise "not implemented"
  else
    raise "unknown state" 
  end
end

File.write("horizon.json", JSON.pretty_generate($book))

#   {
#     "name": "xxx",
#     "prompt": "xxx",
#     "context": "(summary of the story so far, based on other chapter summaries, or the prologue if this is the first chapter)",
#     "summary": "(summary of this chapter)",
#     "scenes": [
#       {
#         "name": "xxx",
#         "prompt": "xxx",
#         "context": "(summary of the chapter so far, based on other scene summaries; blank if this is the first scene)",
#         "summary": "(summary of this scene)",
#         "beats": [{
#           "name": "xxx",
#           "prompt": "xxx",
#         }],
#         "paragraphs": []
#       }
#     ]
#   },
