#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
end

client = OpenAI::Client.new

message = "Creepy hotel lobby with patterns in the wood that contain hidden messages and shelved of books with a mysterious manuscript sitting on a table."

response = client.images.generate(parameters: { prompt: message, size: "1024x1024" })

ap response

response.dig("choices", 0, "message", "content")
