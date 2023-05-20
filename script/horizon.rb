#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

#===============================================================================

def get_response(messages)
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
  end
  client = OpenAI::Client.new
  request =
    {
      model: "gpt-4",
      temperature: 0.7,
      messages: messages
    }
  response = client.chat(parameters: request)
  response.dig("choices", 0, "message", "content")
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
  $book[:state][:name] = "chapters"
end

#===============================================================================

$book = JSON.parse(File.read("horizon.json"), symbolize_names: true)
$book[:state][:changed] = false

while !$book[:state][:changed]
  case $book[:state][:name]
  when "prologue"
    generate_prologue_summary
  when "chapters"
    raise "not implemented"
  when "epilogue"
    raise "not implemented"
  else
    raise "unknown state" 
  end
end

File.write("book.json", JSON.pretty_generate($book))

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
